# Internet Robinhood Lottery ($IRL) | UHI11

IRL is a community lottery and rewards system for a Uniswap v4 pool. The hook turns eligible trading volume and staking into NFT lottery entries. It allocates swap fees to prize pools, hourly trader rewards and claimable ETH yield for stakers.

**Demo network:** Robinhood Chain Testnet (46630). [Preview](https://irlprotocol.xyz/hookathon/) · [Judging guide and testnet readiness](docs/judge-demo.md) · [Audit preparation and test evidence](docs/judge-demo.md#audit-preparation-and-test-evidence)

## How the hook works

- **Volume tickets.** The hook records eligible swap volume and issues a ticket for each 0.10 ETH of credited daily volume, up to the wallet's daily cap. Staking can increase the credited score and the cap. An eligible swap can therefore earn an NFT without a separate lottery entry transaction.
- **Staking tickets.** A staker can claim NFT tickets directly from the hook in four-day periods. A stake of 1 million IRL qualifies for one ticket at the minimum tier, and allowances scale up to ten tickets per period. The staking contract tracks balances and applies the individual claim lock when applicable.
- **Prizes.** The hook funds daily and weekly pots. A draw transaction requests randomness, and the callback selects a ticket in the eligible range. The hook resolves its owner and handles the ETH prize or records a claimable balance if the transfer fails, subject to the lottery's custody rules.
- **Hourly rewards.** The hook credits cashback for eligible traders and score-based rewards for the top ten. Processing the completed hour and paying traders in batches both require upkeep transactions. The staking share goes to the staking contract during the swap. Eligible stakers can withdraw accrued ETH with a claim transaction.

### Standard fee allocation

The inherited V2 hook charges 4% of the swap's WETH volume outside launch boost. The figures below are percentages of swap volume, before rounding. The initial launch schedule uses different rates.

| Allocation | Share of standard swap volume | When a user gets it |
| --- | ---: | --- |
| Trader cashback | 0.4375% | Credited at swap time and settled through hourly upkeep |
| Trader top ten | 0.4375% | Settled by score through hourly upkeep |
| Staking yield | 0.375% | Funded at swap time and claimable by eligible stakers |
| **Trader and staking redistribution** | **1.25%** | **35% cashback, 35% top ten and 30% staking** |
| Daily and weekly lottery | 0.625% each | Paid via the draw flow |
| Protocol pot | 1.30% before referral commissions | Credited at swap time |
| Buyback reserve | 0.20% | Credited at swap time |

The direct-launch contracts credit the former 0.30% platform share to the protocol pot. The buyback execution also credits its existing 30-bps share of buyback funds to the protocol pot. The live page now reads the direct-launch pool and links to its first swap.

## Project history for judges

- **V1 in production** on Robinhood Chain mainnet. [Live site](https://irlprotocol.xyz/) · [V1 GitHub](https://github.com/math-crypt/lottery-robinhood/tree/main) · [On-chain launch evidence and V2 design choices](docs/v1-evidence.md)
- **First V2 for the Hookathon.** This revision supplies the contracts inherited by the submission. [Baseline commit](https://github.com/math-crypt/lottery-robinhood/commit/10182117363a4d6b7a37a81314acde014cd4ea23)
- **Current submission.** The focused repository adds a Robinhood testnet preview, a local demo suite for lottery and rewards, and documentation of the V1 evidence. [Testnet preview](https://irlprotocol.xyz/hookathon/) · [Test scenarios](test/CommunityLottery.t.sol)

## Try the local preview

[Open the app on Robinhood Chain Testnet](https://irlprotocol.xyz/hookathon/). The page reads the current lottery pots and other balances at one block. It links to both NFT ticket paths, the completed daily draw, the trader and staking payouts, and the liquidity seed. For a local preview, run `python -m http.server 8031 --bind 127.0.0.1 --directory site` and open http://127.0.0.1:8031.

## What came from IRL v2

The starting point is Math's first IRL v2 Hookathon version (revision 1018211). Five Solidity source files are retained in src. The token, ticket NFT, staking dependency, swap hook and developer liquidity vault are inherited. The submission keeps both routes to lottery tickets, both draws and trader and staking rewards. One reason for V2 was that V1 could credit a swap router with a trader's ticket. The first V2 introduced trusted router context and an ordinary-wallet fallback. The Hookathon work makes this change and the payout rules reproducible. [V1 evidence and feedback from the workshop](docs/v1-evidence.md#why-v2-changed-reward-attribution)

The direct launch minted one billion IRL to the liquidity vault. It allocated 800 million to a permanent LP position and 200 million to ten conditional LP positions of 20 million each. The vault owns the positions, and Uniswap v4 PoolManager holds the tokens. Only rounding dust went to the burn address. A conditional tier can release when that position is entirely WETH. Each tier is evaluated separately. An opt-in vault that tracks each user's own deposit and withdrawal is a proposed extension. [Liquidity seed receipt](https://explorer.testnet.chain.robinhood.com/tx/0x6315ac16dc9ab00a929495e0bba75ac43bff72b5e80bd1fbbdaefd2b36e6ea46).

## Work during the Hookathon

November 26 — isolated the selected sources, prepared a testnet-only lottery view, added a deployment manifest and verified the testnet chain ID using the official RPC. The local suite was expanded to cover staking ticket claims and hourly redistribution. The direct-launch contracts and all eleven vault positions were deployed on Robinhood Chain Testnet. A live 0.10 WETH swap with empty hook data gave NFT ticket #1 to the trader's wallet and zero tickets to the router. The hook credited 0.000625 ETH to each lottery pot and 0.0013 ETH to the protocol pot.

November 27 — the first direct-launch daily draw requested and received OpenVRF randomness. Ticket #1 won 0.000625 test ETH, paid to its owner. Hourly upkeep then paid the same trader 0.000875 test ETH in cashback plus top-ten rewards. The test wallet staked 1 million IRL, claimed ticket #2 through the hook and withdrew 0.000375 test ETH in staking yield. A public liquidity vault remains proposed work.

## Build and evaluate

After cloning this repository, run `git submodule update --init --recursive` to fetch the pinned dependencies. Foundry settings target Solidity 0.8.26, Cancun and via IR. Run the basic lottery suite from the repository root:

```sh
forge test -j 1 --match-contract CommunityLotteryTest -vv
```

On November 27, 2026, all five scenarios passed with solc 0.8.26 on a local Foundry EVM using the pinned libraries. The fixture uses a v4 PoolManager, a funded IRL/WETH pool, the regular fee schedule and empty hook data.

| Scenario | Observed result |
| --- | --- |
| One wallet spends 0.25 WETH | It receives IRL and owns both tickets. The router owns zero tickets. Each prize pool gains 0.0015625 ETH. |
| One wallet spends 0.06 then 0.04 WETH | It has zero tickets after the first swap and one after reaching 0.10 WETH of volume. |
| Two wallets earn three tickets and the day ends | A deterministic test oracle selects ticket 3. Its owner receives the daily prize of 0.001875 ETH. The weekly pot is preserved. |
| A staker with 1 million IRL claims tickets | The staker receives one NFT, gets no duplicate in the same period, and can claim again in the next four-day period. |
| Two traders swap 0.40 WETH in total while a wallet stakes | Hourly upkeep pays the traders 0.0035 ETH in total. The staker claims the 0.0015 ETH credited during the swaps. |

An earlier Foundry run estimated 36.08% line coverage across the five project contracts (407/1,128), with approximate source mappings in minimum via-IR mode. Coverage was not measured again for the current direct-launch revision. The local daily draw test uses a deterministic randomness callback. The direct-launch pool has also completed a live OpenVRF draw and payout on Robinhood Chain Testnet.

## Partner integrations

No Hookathon partner prize integrations are currently claimed. The testnet deployment uses OpenVRF for live randomness, with the request and callback wired into [the hook](src/IRLUniswapV4Hook.sol) and configured by [the deployment script](script/DeployDirectIRL.s.sol). The [draw receipt](https://explorer.testnet.chain.robinhood.com/tx/0x43b2a2c257099973fd095692a1c290ccb9e95a32e26a4d94a9683ec237567a71) records fulfillment and payout. The Chainlink Automation interface is a code dependency. The recorded hourly upkeep used test transactions.

See the [judging guide](docs/judge-demo.md#live-direct-launch-evidence) for verified contracts, transactions and remaining demo steps.
