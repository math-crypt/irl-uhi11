# What the live V1 taught us

IRL v1 deployed its hook on Robinhood Chain mainnet on 15 October 2026. The live deployment provided data about lottery participation, staking and reward attribution. The Hookathon submission builds on the first V2 revision and uses this evidence to choose what to demonstrate.

[V1 website](https://irlprotocol.xyz/) · [V1 source](https://github.com/math-crypt/lottery-robinhood/tree/main) · [V1 hook creation transaction](https://robinhoodchain.blockscout.com/tx/0xbe661831a40235e527213209da2e1a7cd7f19ac3eb1c2f3a0e11048b6d6b9217) · [First V2 revision](https://github.com/math-crypt/lottery-robinhood/commit/10182117363a4d6b7a37a81314acde014cd4ea23)

## Why V2 changed reward attribution

In V1, some aggregators left the optional `hookData` empty. The hook fell back to Uniswap's `sender` parameter, which identifies the caller of the pool and can be a router. This made the router eligible for the volume-based ticket instead of the wallet that placed the trade. The V1 NFT contract minted ticket 3 directly to a Universal Router. A later draw listed that same router as the winner. [Ticket #3 mint](https://robinhoodchain.blockscout.com/tx/0x3ab4becced8d7ce2c6b70a597c9d842baaff89b757f34080a0cdcabb1f0ce003) · [Daily draw](https://robinhoodchain.blockscout.com/tx/0x168fc0bbbb7f975864e579c3b4e76704c0afe30bde47200c9e4971c73f01bf4e)

Math brought this issue to the UHI11 workshop on 21 October 2026. Tom Wade recommended asking a verified router for the original swap initiator via `IMsgSender.msgSender()`, and allowing the swap to continue when this information is missing. He discussed falling back to the transaction origin for ordinary wallets or skipping the reward when attribution is uncertain. He pointed out that a relayer can submit a Safe transaction on someone else's behalf. [Uniswap's guide to trusted router attribution](https://developers.uniswap.org/docs/protocols/v4/guides/hooks/accessing-msg.sender)

The first V2 already applies this design. The hook tries the buyer context exposed by approved routers, checks a supplied wallet when available, and falls back to the transaction origin for a routed swap without a usable context. The volume ticket path avoids minting directly to the calling router. Staking has its own entry path for eligible stakers. The transaction origin identifies the account that submitted the transaction. Smart wallets and relayed trades still need their own coverage. [V2 trader resolution](../src/IRLUniswapV4Hook.sol#L913)

The Hookathon tests verify the ordinary-wallet case on a local v4 pool. A swap through a router with empty hook data gives the wallet two tickets and leaves the router with zero. The hourly test also verifies the traders' ETH payouts. The testnet demo will use these same checks alongside the draw and payout receipts. [Tests](../test/CommunityLottery.t.sol)

## Mainnet snapshot

Robinhood Chain (4663), [block 123615181](https://robinhoodchain.blockscout.com/block/123615181), 26 November 2026 at 13:02:04 UTC.

| Observation | Source | How it informs V2 |
| --- | --- | --- |
| 205 NFT tickets minted over the lifetime of the V1 contract | [V1 ticket contract](https://robinhoodchain.blockscout.com/address/0x837170cDdED801F491855405CbcfDA1211d812D7), `totalTicketsMinted()` | Keep NFT entry visible and test both routes to earning a ticket. This count includes all mint paths. |
| 9 daily and 5 weekly winner events, with prize fields totaling 0.714491100288670153 ETH and 0.720250395682801733 ETH respectively | [V1 hook logs](https://robinhoodchain.blockscout.com/address/0xAb64c6Eb29a6bb8488cb1fcAB1ca11C5e28bC0cc?tab=logs) | Preserve both prize pools and verify that a draw creates the expected balance change for the winner. |
| 14,288,077 IRL staked at the snapshot block | [V1 staking contract](https://robinhoodchain.blockscout.com/address/0x15958AC04ABA8D58C21BfD2760315A6a7D9E395d), `totalStaked()` | Keep staking tickets and claimable ETH yield in the demo. Demonstrate staking and liquidity provision as separate actions. |
| One daily draw names a Universal Router contract as winner of ticket 3 | [V1 draw transaction](https://robinhoodchain.blockscout.com/tx/0x168fc0bbbb7f975864e579c3b4e76704c0afe30bde47200c9e4971c73f01bf4e) | Test the common V2 case where a wallet swaps via a router that sends empty hook data, and check ownership and rewards at the wallet. |

Ticket and staking totals come from read-only calls pinned to the snapshot block. Winner counts come from the V1 hook's `LotteryWinnerDrawn` and `SundayMegaJackpotDrawn` logs, starting at the hook's creation block 88826221. Each log's prize field was summed as integer wei. These are emitted prize amounts. Verifying actual payments or claims requires following the transfers and claim state. The linked mint confirms the first owner of ticket 3. The mint and draw receipts establish ownership and the logged winner. The workshop and V1 code explain the attribution rule. Ticket count measures mints, and staking measures token balances at a point in time.

The V2 tests in this repository reproduce the intended outcomes on a local v4 pool. The Robinhood testnet deployment and live randomness provider will have their own receipts.
