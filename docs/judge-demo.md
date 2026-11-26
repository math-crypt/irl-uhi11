# Internet Robinhood Lottery ($IRL) — judging guide

The demo target is **Robinhood Chain Testnet (46630)**. The deployed V1 history is on Robinhood Chain mainnet (4663). The testnet deployment uses the same IRL name and symbol, with separate contracts and test funds.

## Reproduce the current results locally

1. Clone this repository, initialize submodules recursively, then run `forge test -j 1 --match-contract CommunityLotteryTest -vv`.
2. For the V1-to-V2 comparison, run `forge test -j 1 --match-test testSwapFundsBothPotsAndMintsTwoTickets -vvvv`. Follow the swap through the test router to the hook. Check both NFT owners and the daily and weekly prize pots.
3. Run `testStakerCanClaimOneNFTPerFourDayEpochAtMinimumStake` to see the second path to a lottery ticket. Run `testSwapFeesPayTradersHourlyAndFundClaimableStakingYield` to check ETH balances after the hour is processed and after the staker claims.
4. Run `testDailyDrawPaysOwnerOfWinningTicket` to follow the daily prize to the wallet that owns the winner NFT. This test uses a deterministic randomness callback so that the payout is reproducible.

[Exact scenarios](../test/CommunityLottery.t.sol) · [V1 mint and draw receipts and Tom Wade's workshop advice](v1-evidence.md#why-v2-changed-reward-attribution)

## Robinhood testnet readiness

Read-only checks on 26 November 2026 confirmed chain ID 46630. The PoolManager at `0x8366a39CC670B4001A1121B8F6A443A643e40951` returned runtime bytecode identical to the Robinhood mainnet PoolManager listed by Uniswap. The PositionManager at `0x58daec3116aae6d93017baaea7749052e8a04fa7` and StateView at `0xF3334192D15450CdD385c8B70e03f9A6bD9E673b` each returned that PoolManager. These are observed testnet contracts. The intended swap route and settlement still require a test transaction. [Robinhood network details](https://docs.robinhood.com/chain/add-network-to-wallet/) · [Uniswap's v4 deployment list](https://developers.uniswap.org/docs/protocols/v4/deployments)

The V1 WETH and OpenVRF addresses have no code on chain 46630. Before broadcasting, verify a compatible testnet wrapper and a randomness provider supported by the hook. A deterministic provider is suitable for a clearly labelled payout demonstration. A verifiable draw requires the live request and fulfillment path to be separately validated.

## What the filmed testnet demo should show

| Scene | Evidence to retain |
| --- | --- |
| Swap and lottery entry | Chain ID, pool ID, swap receipt, the wallet's NFT and both pot balances before and after. |
| Staking and rewards | Staking ticket claim, swap-funded ETH yield, hourly upkeep and a trader payout, plus a staker claim. |
| Daily draw | Randomness request and fulfillment, the winning ticket's owner, and the payout or claim receipt. |
| Optional liquidity vault | A voluntary deposit and the withdrawal condition on a real position if the prototype is ready. |

[Robinhood testnet preview](https://irlprotocol.xyz/hookaton/) currently shows deployment status. Add the deployed addresses and explorer receipts once the testnet flow runs. The local suite is available now.
