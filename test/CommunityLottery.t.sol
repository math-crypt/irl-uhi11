// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {InternetRobinLottery} from "../src/InternetRobinLottery.sol";
import {IRLStaking} from "../src/IRLStaking.sol";
import {IRLTicketNFT} from "../src/IRLTicketNFT.sol";
import {IRLUniswapV4Hook} from "../src/IRLUniswapV4Hook.sol";

contract DemoRandomness {
    uint256 public lastRequest;
    function requestFee() external pure returns (uint256) { return 0; }
    function requestRandomness(uint32) external payable returns (uint256) { return ++lastRequest; }
}

contract CommunityLotteryTest is Test {
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant STAKER = address(0xCA401);
    IRLStaking staking;
    WETH weth;
    InternetRobinLottery irl;
    IRLTicketNFT tickets;
    IRLUniswapV4Hook hook;
    PoolKey key;
    PoolSwapTest router;
    DemoRandomness oracle;

    function setUp() public {
        vm.warp(20000 days);
        PoolManager manager = PoolManager(deployCode("PoolManager.sol:PoolManager", abi.encode(address(this))));
        router = PoolSwapTest(payable(deployCode("PoolSwapTest.sol:PoolSwapTest", abi.encode(manager))));
        PoolModifyLiquidityTest lp = PoolModifyLiquidityTest(payable(deployCode("PoolModifyLiquidityTest.sol:PoolModifyLiquidityTest", abi.encode(manager))));
        weth = new WETH();
        irl = new InternetRobinLottery(address(this), 1_000_100 ether);
        tickets = IRLTicketNFT(deployCode("IRLTicketNFT.sol:IRLTicketNFT", abi.encode(address(this))));
        oracle = new DemoRandomness();
        staking = IRLStaking(payable(deployCode("IRLStaking.sol:IRLStaking", abi.encode(address(irl)))));
        address flags = address(0x10000cc);
        deployCodeTo("IRLUniswapV4Hook.sol:IRLUniswapV4Hook", abi.encode(manager, tickets, staking, oracle, weth), flags);
        hook = IRLUniswapV4Hook(payable(flags));
        tickets.transferOwnership(flags);
        hook.removeLimits(); // The regular fee schedule. Launch boost is outside these scenarios.
        bool wethFirst = address(weth) < address(irl);
        key = PoolKey(Currency.wrap(wethFirst ? address(weth) : address(irl)),
            Currency.wrap(wethFirst ? address(irl) : address(weth)), 3000, 60, IHooks(flags));
        manager.initialize(key, uint160(1 << 96));
        vm.deal(address(this), 1_000_100 ether);
        weth.deposit{value: 50 ether}();
        weth.approve(address(lp), type(uint256).max);
        irl.approve(address(lp), type(uint256).max);
        lp.modifyLiquidity(key, ModifyLiquidityParams(-6000, 6000, int256(50 ether), bytes32(0)), "");
    }

    function buy(address buyer, uint256 amount) internal {
        vm.deal(buyer, amount);
        vm.startPrank(buyer, buyer);
        weth.deposit{value: amount}();
        weth.approve(address(router), amount);
        bool zeroForOne = Currency.unwrap(key.currency0) == address(weth);
        router.swap(key, SwapParams(zeroForOne, -int256(amount),
            zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1),
            PoolSwapTest.TestSettings(false, false), "");
        vm.stopPrank();
    }

    function testSwapFundsBothPotsAndMintsTwoTickets() public {
        address oldFeeRecipient = 0xD88539d3c4C460136a733A3Fd60cf6BF269079da;
        uint256 previousFeeBalance = oldFeeRecipient.balance;
        buy(ALICE, 0.25 ether);
        assertGt(irl.balanceOf(ALICE), 0);
        assertEq(oldFeeRecipient.balance, previousFeeBalance);
        assertEq(hook.protocolPot(), 0.00325 ether);
        assertEq(hook.buybackPot(), 0.0005 ether);
        assertEq(tickets.balanceOf(ALICE), 2);
        assertEq(tickets.ownerOf(1), ALICE);
        assertEq(tickets.ownerOf(2), ALICE);
        assertEq(tickets.balanceOf(address(router)), 0);
        assertEq(hook.dailyLotteryPot(), 0.0015625 ether);
        assertEq(hook.sundayMegaPot(), 0.0015625 ether);
    }

    function testTwoSmallerSwapsReachOneTicket() public {
        buy(ALICE, 0.06 ether);
        assertEq(tickets.balanceOf(ALICE), 0);
        buy(ALICE, 0.04 ether);
        assertEq(tickets.balanceOf(ALICE), 1);
        assertEq(hook.dailyLotteryPot(), 0.000625 ether);
    }

    function testDailyDrawPaysOwnerOfWinningTicket() public {
        buy(ALICE, 0.2 ether);
        buy(BOB, 0.1 ether);
        assertEq(tickets.ownerOf(3), BOB);
        uint256 daily = hook.dailyLotteryPot();
        uint256 weekly = hook.sundayMegaPot();
        uint256 beforeBob = BOB.balance;
        uint256 beforeAlice = ALICE.balance;
        vm.warp(block.timestamp + 1 days);
        hook.performUpkeep(abi.encode(uint8(3), uint256(0)));
        assertEq(oracle.lastRequest(), 1);
        vm.prank(address(oracle));
        hook.rawFulfillRandomness(1, 2); // IDs 1..3, deterministic word selects #3.
        assertEq(daily, 0.001875 ether);
        assertEq(BOB.balance - beforeBob, daily);
        assertEq(ALICE.balance, beforeAlice);
        assertEq(hook.sundayMegaPot(), weekly);
    }

    function stakeForLottery() internal {
        irl.transfer(STAKER, 1_000_000 ether);
        vm.startPrank(STAKER);
        irl.approve(address(staking), 1_000_000 ether);
        staking.stake(1_000_000 ether);
        vm.stopPrank();
    }

    function testStakerCanClaimOneNFTPerFourDayEpochAtMinimumStake() public {
        stakeForLottery();
        vm.startPrank(STAKER);
        hook.claimStakingTickets();
        assertEq(tickets.ownerOf(1), STAKER);
        hook.claimStakingTickets();
        assertEq(tickets.balanceOf(STAKER), 1);
        vm.warp(block.timestamp + 4 days);
        hook.claimStakingTickets();
        vm.stopPrank();
        assertEq(tickets.ownerOf(2), STAKER);
    }

    function testSwapFeesPayTradersHourlyAndFundClaimableStakingYield() public {
        stakeForLottery();
        buy(ALICE, 0.25 ether);
        buy(BOB, 0.15 ether);

        assertEq(staking.pendingYield(STAKER), 0.0015 ether);
        assertEq(hook.hourlyRewardPot(), 0.00175 ether);
        assertEq(ALICE.balance, 0);
        assertEq(BOB.balance, 0);

        vm.warp(block.timestamp + 1 hours);
        hook.performUpkeep(abi.encode(uint8(1), uint256(0)));
        assertEq(hook.buybackPot(), 0);
        assertEq(hook.protocolPot(), 0.0052024 ether);
        hook.performUpkeep(abi.encode(uint8(2), uint256(0)));

        // Both traders rank in the top ten. Each receives their volume-based cashback and ranking share.
        assertEq(ALICE.balance, 0.0021875 ether);
        assertEq(BOB.balance, 0.0013125 ether);

        uint256 beforeClaim = STAKER.balance;
        vm.prank(STAKER);
        staking.claimYield();
        assertEq(STAKER.balance - beforeClaim, 0.0015 ether);
        assertEq(staking.pendingYield(STAKER), 0);
    }
}
