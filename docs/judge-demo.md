# Internet Robinhood Lottery ($IRL) — judging guide

The demo target is **Robinhood Chain Testnet (46630)**. The deployed V1 history is on Robinhood Chain mainnet (4663). The testnet deployment uses the same IRL name and symbol, with separate contracts and test funds.

## Reproduce the current results locally

1. Clone this repository, initialize submodules recursively, then run `forge test -j 1 --match-contract CommunityLotteryTest -vv`.
2. For the V1-to-V2 comparison, run `forge test -j 1 --match-test testSwapFundsBothPotsAndMintsTwoTickets -vvvv`. Follow the swap through the test router to the hook. Check both NFT owners and the daily and weekly prize pots.
3. Run `testStakerCanClaimOneNFTPerFourDayEpochAtMinimumStake` to see the second path to a lottery ticket. Run `testSwapFeesPayTradersHourlyAndFundClaimableStakingYield` to check ETH balances after the hour is processed and after the staker claims.
4. Run `testDailyDrawPaysOwnerOfWinningTicket` to follow the daily prize to the wallet that owns the winner NFT. This test uses a deterministic randomness callback so that the payout is reproducible.

[Exact scenarios](../test/CommunityLottery.t.sol) · [V1 mint and draw receipts and Tom Wade's workshop advice](v1-evidence.md#why-v2-changed-reward-attribution)

## Audit preparation and test evidence

Scope: the IRL v2 direct-launch Hookathon checkout and its Robinhood Chain Testnet deployment. On November 27, `forge test -j 1 --offline --match-contract CommunityLotteryTest -vv` returned **5 passed, 0 failed, 0 skipped**. The integration fixture runs the hook through a v4 PoolManager and checks ownership and balances before and after each action. [Test source](../test/CommunityLottery.t.sol)

| Behavior | Applied and passed in Foundry | Confirmed on Robinhood Chain Testnet |
| --- | --- | --- |
| Trader attribution and fee allocation | A 0.25 WETH swap gives the trader two NFTs, gives the router zero, funds both lottery pots and checks the direct protocol and buyback shares. | A 0.10 WETH swap with empty hook data gave ticket #1 to the wallet and zero to the router. Daily and weekly pots each received 0.000625 ETH. |
| Cumulative volume threshold | Swaps of 0.06 and 0.04 WETH give zero tickets after the first swap and one after reaching the threshold. | The single swap hit the threshold. The two-swap sequence was checked locally. |
| Daily draw | A deterministic callback selects ticket #3. The prize reaches its owner and the weekly pot stays funded. | Live OpenVRF request #2 selected the only eligible ticket, #1, and paid its owner 0.000625 test ETH. |
| Staking ticket | The minimum stake earns one ticket. Repeating the claim in the same period earns none. A new four-day period allows a new ticket. | A 1 million IRL stake produced ticket #2 and activated the 24-hour unstake lock on that deposit. |
| Hourly rewards and staking yield | Checks two traders' actual ETH receipts, the staker's yield claim and the protocol share from buyback. | Hourly upkeep paid one trader 0.000875 test ETH. The staker claimed 0.000375 test ETH. |
| Launch liquidity | The separate deployment simulation asserted all eleven positions and supply custody. | The seed transaction confirmed one permanent 80% position and ten conditional 2% positions. |

The transaction receipts, NFT owners and on-chain amounts are linked under [live direct-launch evidence](#live-direct-launch-evidence). The live draw had one eligible ticket, so the three-ticket selection case is evidenced by Foundry. The five scenarios are integration tests; they establish the results of the listed cases. The earlier 36.08% line coverage estimate predates the latest run and was not remeasured.

**Open for audit:** review ticket claim authorization and pool isolation on the scoped revision. Add coverage for smart wallets and relayed swaps, the weekly payout and failed-payout recovery, and run accounting properties across swap directions, amounts and periods. Use fuzz tests for thresholds and rounding, and stateful invariants for fee conservation and staking solvency. The public vault deposit is outside the tested launch scope. Before handing the code to an auditor, pin the release commit and dependencies and attach the command output, chain ID, contract addresses and transaction receipts.

## Robinhood testnet readiness

Read-only checks on 26 November 2026 confirmed chain ID 46630. The PoolManager at `0x8366a39CC670B4001A1121B8F6A443A643e40951` returned runtime bytecode identical to the Robinhood mainnet PoolManager listed by Uniswap. The PositionManager at `0x58daec3116aae6d93017baaea7749052e8a04fa7` and StateView at `0xF3334192D15450CdD385c8B70e03f9A6bD9E673b` each returned that PoolManager. These are observed testnet contracts. The direct-launch swap is now confirmed by a transaction receipt below. [Robinhood network details](https://docs.robinhood.com/chain/add-network-to-wallet/) · [Uniswap's v4 deployment list](https://developers.uniswap.org/docs/protocols/v4/deployments)

The V1 WETH and OpenVRF addresses have no code on chain 46630. The direct-launch pool uses testnet WETH at `0xd07039E14680F32FAbCC78a7084E0aa58d4255A9` and a separately deployed [OpenVRF coordinator](https://explorer.testnet.chain.robinhood.com/address/0x3916d8Dd5543c811DfE58a53Fd01D3812804F1AA). The coordinator passed a live smoke test and has now fulfilled the direct-launch pool's first daily draw.

## What the filmed testnet demo should show

| Scene | Evidence to retain |
| --- | --- |
| Swap and lottery entry | Chain ID, pool ID, swap receipt, the wallet's NFT and both pot balances before and after. |
| Staking and rewards | Staking ticket claim, swap-funded ETH yield, hourly upkeep and a trader payout, plus a staker claim. |
| Daily draw | Randomness request and fulfillment, the winning ticket's owner, and the payout or claim receipt. |
| Optional liquidity vault | A voluntary deposit and the withdrawal condition on a real position if the prototype is ready. |

## Live direct-launch evidence

[The Robinhood Testnet page](https://irlprotocol.xyz/hookathon/) reads the pots at one chain block and links to the direct-launch contracts and transactions. [The liquidity seed](https://explorer.testnet.chain.robinhood.com/tx/0x6315ac16dc9ab00a929495e0bba75ac43bff72b5e80bd1fbbdaefd2b36e6ea46) created eleven vault-owned positions: one permanent position containing 80% of the supply and ten conditional positions containing 2% each. The developer wallet held none of the new IRL supply after seeding; it later acquired IRL through the documented test swap.

[The 0.10 WETH swap](https://explorer.testnet.chain.robinhood.com/tx/0x16febc683716c2bce316530ce9c748c56baed054350575435bd269de1fe5485f) used empty hook data and delivered 11,549,072.709493075939369498 IRL plus [ticket #1](https://explorer.testnet.chain.robinhood.com/token/0x76D0dAfeFaf08C2957ac8CD1f520A6EdF791bEA7/instance/1) to the trader's wallet. The test router received zero tickets. The 0.004 ETH hook fee credited 0.000625 ETH to each lottery pot, 0.0004375 ETH to trader cashback, 0.0004375 ETH to the top-ten pot, 0.000375 ETH to staking, 0.0013 ETH to the protocol pot and 0.0002 ETH to buyback. These are the swap-time allocations. The completed payouts are evidenced separately below.

On 27 November, the hook [requested daily randomness](https://explorer.testnet.chain.robinhood.com/tx/0x5fd2222c2a21e2411df50ffe61596ee814db74bcabfdddebecde1f51fd025c39) for the previous UTC day, whose eligible range contained only ticket #1. OpenVRF round 22759618 [fulfilled the request](https://explorer.testnet.chain.robinhood.com/tx/0x43b2a2c257099973fd095692a1c290ccb9e95a32e26a4d94a9683ec237567a71). The winner event names ticket #1 and its owner with a 0.000625 test ETH prize. The hook's native balance decreased by exactly 0.000625 ETH in the fulfillment block, and the winner's unclaimed balance remained zero.

The hook then [processed the swap hour](https://explorer.testnet.chain.robinhood.com/tx/0x73b8dd01fca8b42f4ded69f3ba2cdaa86d90b61a0b684c485a48216086f69116), allocating 0.0004375 ETH to the top trader and executing the reserved buyback. A separate [payout transaction](https://explorer.testnet.chain.robinhood.com/tx/0x89e340e1def99457befab671e0f1e14062d2cea01cf8db3bb2031322a053acc5) sent 0.000875 ETH to that trader: 0.0004375 cashback plus 0.0004375 top-ten reward. The queue finished at 1/1 and the hook's native balance fell by exactly 0.000875 ETH in the payout block.

The same wallet then [staked 1,000,000 IRL](https://explorer.testnet.chain.robinhood.com/tx/0x6eb999109a8b7d8c00e6c855e7df8926c078104f731fce3f73622c6e60a77a66), [claimed ticket #2](https://explorer.testnet.chain.robinhood.com/tx/0x34c80a07e1f49dfea6fd302260c28bafac094a172f974fb3ebae7fef3f87d108) through the hook and [claimed 0.000375 test ETH](https://explorer.testnet.chain.robinhood.com/tx/0x28019b7526af353f0826fa8181b5394d788a2f8042887106ed87239bca40cda8) of buffered staking yield. The staking contract's native balance fell from 0.000375 ETH to zero in the claim block. An immediate staking-ticket claim applies the contract's 24-hour unstake lock to that test deposit.

The original demo pool's LP was removed in [this transaction](https://explorer.testnet.chain.robinhood.com/tx/0x1ad14c92708561a89cbbc1f53ae2cbd9be1ece58f5b31c3be90ec3f910666399), returning 0.047896996320927879 WETH and 0.047510273175482816 old IRL. That pool and token are separate from the direct-launch deployment.

The [token](https://explorer.testnet.chain.robinhood.com/address/0xAB2b06c9c11871eBB2F8ED9Be359575A4fD672Bf), [hook](https://explorer.testnet.chain.robinhood.com/address/0xb8E6355D71D235EF69Cea5BEE7132853DCA680cC), [ticket NFT](https://explorer.testnet.chain.robinhood.com/address/0x76D0dAfeFaf08C2957ac8CD1f520A6EdF791bEA7), [staking contract](https://explorer.testnet.chain.robinhood.com/address/0xF3d29D15f57ac1a889fB512F8617DdF0Ca6f5414), [vault](https://explorer.testnet.chain.robinhood.com/address/0xF9F15ad01501D7f25078C2E82D84769a12177779) and [testnet swap router](https://explorer.testnet.chain.robinhood.com/address/0xeC390962Fd5c5F0Cbd3D58b282b823E7060F21E6) all show verified source code on the testnet explorer.


## Direct-launch revision

The new hook keeps the former platform share in the protocol pot. `script/DeployDirectIRL.s.sol` reproduces the initial deployment on Robinhood Chain Testnet. The script reads IRL_TESTNET_DEPLOYER, IRL_TESTNET_POOL_MANAGER, IRL_TESTNET_POSITION_MANAGER, IRL_TESTNET_WETH and IRL_TESTNET_OPENVRF. It deploys the vault, token, tickets, staking and hook and authorizes the hook in the existing coordinator. The vault receives all one billion IRL at mint time. Its final launch transaction initializes the pool and creates eleven single-sided Uniswap v4 positions, with 800M IRL allocated to the permanent position and 20M to each of the ten conditional positions. Rounding dust goes to the burn address. The vault owns the positions and PoolManager holds the tokens. The site manifest now uses `feePolicy: direct` and the confirmed direct-launch swap. The test-only router in `src/IRLTestnetSwapRouter.sol` settles WETH before calling the swap on this IRL-only pool.
