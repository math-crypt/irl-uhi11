// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IRLUniswapV4Hook} from "../src/IRLUniswapV4Hook.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IRLMarketingVault} from "../src/IRLMarketingVault.sol";
import {IRLStaking} from "../src/IRLStaking.sol";
import {IRLTicketNFT} from "../src/IRLTicketNFT.sol";
import {InternetRobinLottery} from "../src/InternetRobinLottery.sol";

interface ITestnetPositionManager {
    function poolManager() external view returns (address);
}

interface ITestnetOpenVRF {
    function owner() external view returns (address);
    function setConsumerAuthorization(address consumer, bool authorized) external;
}

contract DeployDirectIRL is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 ether;
    uint160 private constant INITIAL_PRICE_IRL_TOKEN0 = 7158327914619714881093632;
    uint160 private constant INITIAL_PRICE_IRL_TOKEN1 = 876895058097984813589920800000000;

    bytes32 private constant CREATE2_RUNTIME_HASH =
        keccak256(hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3");

    function run() external {
        require(block.chainid == 46630, "Robinhood Chain Testnet only");
        require(CREATE2_FACTORY.codehash == CREATE2_RUNTIME_HASH, "Unexpected CREATE2 factory");
        address deployer = vm.envAddress("IRL_TESTNET_DEPLOYER");
        IPoolManager manager = IPoolManager(vm.envAddress("IRL_TESTNET_POOL_MANAGER"));
        address positionManager = vm.envAddress("IRL_TESTNET_POSITION_MANAGER");
        address weth = vm.envAddress("IRL_TESTNET_WETH");
        ITestnetOpenVRF vrf = ITestnetOpenVRF(vm.envAddress("IRL_TESTNET_OPENVRF"));
        require(address(manager).code.length != 0 && weth.code.length != 0, "Missing testnet infrastructure");
        require(ITestnetPositionManager(positionManager).poolManager() == address(manager), "Wrong PositionManager");
        require(vrf.owner() == deployer, "Deployer must own OpenVRF");

        vm.startBroadcast(deployer);
        IRLMarketingVault vault = new IRLMarketingVault(address(manager), positionManager, address(0));
        InternetRobinLottery token = new InternetRobinLottery(address(vault), INITIAL_SUPPLY);
        vault.setIrlToken(address(token));
        IRLTicketNFT tickets = new IRLTicketNFT(deployer);
        IRLStaking staking = new IRLStaking(address(token));
        IRLUniswapV4Hook hook = deployHook(manager, tickets, staking, vrf, weth);
        require(hook.owner() == deployer && staking.hookContract() == address(hook), "Unexpected ownership");
        tickets.transferOwnership(address(hook));
        hook.setEcosystemContracts(address(token), address(vault));
        vrf.setConsumerAuthorization(address(hook), true);
        // Testnet demo uses the standard fee schedule.
        hook.removeLimits();

        bool irlIsToken0 = address(token) < weth;
        (address first, address second) = irlIsToken0 ? (address(token), weth) : (weth, address(token));
        PoolKey memory key = PoolKey(Currency.wrap(first), Currency.wrap(second), 3000, 60, IHooks(address(hook)));
        vault.initializeAndSeed(key, irlIsToken0 ? INITIAL_PRICE_IRL_TOKEN0 : INITIAL_PRICE_IRL_TOKEN1);
        vm.stopBroadcast();

        verifySeed(manager, key.toId(), token, vault, deployer);
        console2.log("Demo liquidity vault", address(vault));

        console2.log("Demo token", address(token));
        console2.log("Demo tickets", address(tickets));
        console2.log("Demo staking", address(staking));
        console2.log("Demo hook", address(hook));
        console2.logBytes32(PoolId.unwrap(key.toId()));
    }

    function verifySeed(
        IPoolManager manager, PoolId id, InternetRobinLottery token, IRLMarketingVault vault, address deployer
    ) private view {
        require(vault.liquiditySeeded(), "Vault initialization failed");
        require(token.balanceOf(deployer) == 0 && token.balanceOf(address(vault)) == 0, "Unallocated IRL");
        uint256 dust = token.balanceOf(vault.DEAD_ADDRESS());
        require(dust <= 0.001 ether, "Unexpected allocation rounding");
        require(token.balanceOf(address(manager)) + dust == INITIAL_SUPPLY, "Incomplete supply allocation");
        (uint128 locked,,) = manager.getPositionInfo(
            id, address(vault), vault.permanentTickLower(), vault.permanentTickUpper(), vault.PERMANENT_LOCKED_SALT()
        );
        require(locked != 0 && locked == vault.permanentLiquidity(), "Permanent position missing");
        for (uint256 i; i < vault.NUM_MARKETING_TIERS(); ++i) {
            (uint128 tier,,) = manager.getPositionInfo(
                id, address(vault), vault.tierTickLower(i), vault.tierTickUpper(i), vault.getTierSalt(i)
            );
            require(tier != 0 && tier == vault.tierLiquidity(i), "Conditional position missing");
        }

        console2.log("IRL in PoolManager (base units)", token.balanceOf(address(manager)));
        console2.log("Rounding dust sent to burn address (base units)", dust);
    }

    function deployHook(IPoolManager manager, IRLTicketNFT tickets, IRLStaking staking, ITestnetOpenVRF vrf, address weth)
        private
        returns (IRLUniswapV4Hook)
    {
        bytes memory initCode = abi.encodePacked(
            vm.getCode("IRLUniswapV4Hook.sol:IRLUniswapV4Hook"),
            abi.encode(manager, address(tickets), address(staking), address(vrf), weth)
        );
        bytes32 initHash = keccak256(initCode);
        for (uint256 i; i < 1_000_000; ++i) {
            bytes32 salt = bytes32(i);
            address predicted = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", CREATE2_FACTORY, salt, initHash)))));
            if ((uint160(predicted) & 0x3fff) != 0x00cc || predicted.code.length > 0) continue;
            (bool ok,) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
            require(ok && predicted.code.length != 0, "Hook deployment failed");
            return IRLUniswapV4Hook(payable(predicted));
        }
        revert("No hook salt found");
    }
}
