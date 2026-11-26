# Internet Robinhood Lottery ($IRL) | UHI11

IRL is a community lottery and rewards system for a Uniswap v4 pool. The hook turns eligible trading volume and staking into NFT lottery entries. It allocates swap fees to prize pools, hourly trader rewards and claimable ETH yield for stakers.

**Demo network:** Robinhood Chain Testnet (46630). [Preview](https://irlprotocol.xyz/hookaton/) · [Judging guide and testnet readiness](docs/judge-demo.md)

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

The remaining fee covers other V2 allocations. This table describes the contracts in this repository.

## Project history for judges

- **V1 in production** on Robinhood Chain mainnet. [Live site](https://irlprotocol.xyz/) · [V1 GitHub](https://github.com/math-crypt/lottery-robinhood/tree/main) · [On-chain launch evidence and V2 design choices](docs/v1-evidence.md)
- **First V2 for the Hookathon.** This revision supplies the contracts inherited by the submission. [Baseline commit](https://github.com/math-crypt/lottery-robinhood/commit/10182117363a4d6b7a37a81314acde014cd4ea23)
- **Current submission.** The focused repository adds a Robinhood testnet preview, a local demo suite for lottery and rewards, and documentation of the V1 evidence. [Testnet preview](https://irlprotocol.xyz/hookaton/) · [Test scenarios](test/CommunityLottery.t.sol)

## Try the local preview

[Open the testnet preview](https://irlprotocol.xyz/hookaton/). For a local preview, from this directory run `python -m http.server 8031 --bind 127.0.0.1 --directory site` and open http://127.0.0.1:8031. The preview needs no wallet. It shows deployment status until a verified testnet hook is recorded in `site/deployment.json`. Once configured, reload to read both prize pools at the same Robinhood Chain Testnet block. Balances are denominated in test ETH. The fork has no recorded deployment yet.

## What came from IRL v2

The starting point is Math's first IRL v2 Hookathon version (revision 1018211). Five Solidity source files are retained in src. The token, ticket NFT, staking dependency, swap hook and developer liquidity vault are inherited. The submission keeps both routes to lottery tickets, both draws and trader and staking rewards. One reason for V2 was that V1 could credit a swap router with a trader's ticket. The first V2 introduced trusted router context and an ordinary-wallet fallback. The Hookathon work makes this change and the payout rules reproducible. [V1 evidence and feedback from the workshop](docs/v1-evidence.md#why-v2-changed-reward-attribution)

The developer vault divides liquidity into permanent and conditional allocations. A conditional tier can release when that position is entirely WETH. Each tier is evaluated separately. An opt-in vault that tracks each user's own deposit and withdrawal is a proposed extension.

## Work during the Hookathon

November 26 — isolated the selected sources, prepared a testnet-only lottery view, added a deployment manifest and verified the testnet chain ID using the official RPC. The testnet interface uses the IRL logo from the existing site. The local suite was expanded to cover staking ticket claims and hourly redistribution. The testnet hook deployment, frontend connection and public vault are pending.

## Build and evaluate

After cloning this repository, run `git submodule update --init --recursive` to fetch the pinned dependencies. Foundry settings target Solidity 0.8.26, Cancun and via IR. Run the basic lottery suite from the repository root:

```sh
forge test -j 1 --match-contract CommunityLotteryTest -vv
```

On November 26, 2026, all five scenarios passed with solc 0.8.26 on a local Foundry EVM using the pinned libraries. The fixture uses a v4 PoolManager, a funded IRL/WETH pool, the regular fee schedule and empty hook data.

| Scenario | Observed result |
| --- | --- |
| One wallet spends 0.25 WETH | It receives IRL and owns both tickets. The router owns zero tickets. Each prize pool gains 0.0015625 ETH. |
| One wallet spends 0.06 then 0.04 WETH | It has zero tickets after the first swap and one after reaching 0.10 WETH of volume. |
| Two wallets earn three tickets and the day ends | A deterministic test oracle selects ticket 3. Its owner receives the daily prize of 0.001875 ETH. The weekly pot is preserved. |
| A staker with 1 million IRL claims tickets | The staker receives one NFT, gets no duplicate in the same period, and can claim again in the next four-day period. |
| Two traders swap 0.40 WETH in total while a wallet stakes | Hourly upkeep pays the traders 0.0035 ETH in total. The staker claims the 0.0015 ETH credited during the swaps. |

Foundry estimates 36.08% line coverage across the five project contracts (407/1,128), with approximate source mappings in minimum via-IR mode. The daily draw test uses a deterministic randomness callback. Live randomness and Robinhood testnet settlement require separate verification.

Dependencies include Uniswap v4 core and periphery and OpenZeppelin Contracts. The inherited hook also imports a Chainlink Automation interface and exposes an OpenVRF request/callback path. A library import alone does not demonstrate a live partner integration. Document the actual randomness provider, fulfillment, tests, partner links and deployment transactions for the released version.

See the [testnet readiness checks](docs/judge-demo.md#robinhood-testnet-readiness) for verified infrastructure and the remaining dependencies.
