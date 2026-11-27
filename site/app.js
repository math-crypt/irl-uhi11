const status = document.querySelector("#status");
const rpc = "https://rpc.testnet.chain.robinhood.com";
const explorer = "https://explorer.testnet.chain.robinhood.com";
const isAddress = value => typeof value === "string" && /^0x[0-9a-f]{40}$/i.test(value);
async function read(method, params = []) {
  const response = await fetch(rpc, {
    method: "POST", headers: {"Content-Type": "application/json"},
    body: JSON.stringify({jsonrpc: "2.0", id: 1, method, params}),
    signal: AbortSignal.timeout(10000)
  });
  if (!response.ok) throw new Error("The testnet is unavailable.");
  const message = await response.json();
  if (message.error || typeof message.result !== "string") throw new Error("The testnet read failed.");
  return message.result;
}
function formatEther(hex) {
  if (!/^0x[0-9a-f]{1,64}$/i.test(hex)) throw new Error("Unexpected balance response.");
  const digits = BigInt(hex).toString().padStart(19, "0");
  const fraction = digits.slice(-18).replace(/0+$/, "");
  return digits.slice(0, -18) + (fraction ? "." + fraction : "") + " ETH";
}
function showProof(config) {
  const {hook, staking, tickets, openVRF, token, vault, router, demoSwap, demoTicket, launch,
    dailyDrawRequest, dailyDrawPayout, hourlySetup, hourlyPayout,
    stakingDeposit, stakingTicketClaim, stakingTicket, stakingYieldClaim} = config;
  if (![hook, staking, tickets, openVRF, token, vault, router].every(isAddress) ||
      typeof demoSwap !== "string" || !/^0x[0-9a-f]{64}$/i.test(demoSwap) ||
      typeof launch !== "string" || !/^0x[0-9a-f]{64}$/i.test(launch) ||
      ![dailyDrawRequest, dailyDrawPayout, hourlySetup, hourlyPayout,
        stakingDeposit, stakingTicketClaim, stakingYieldClaim].every(value =>
        typeof value === "string" && /^0x[0-9a-f]{64}$/i.test(value)) ||
      !Number.isSafeInteger(demoTicket) || demoTicket < 1 ||
      !Number.isSafeInteger(stakingTicket) || stakingTicket < 1) return;
  for (const [id, route] of Object.entries({
    "swap-link": "/tx/" + demoSwap,
    "ticket-link": "/token/" + tickets + "/instance/" + demoTicket,
    "hook-link": "/address/" + hook, "token-link": "/token/" + token,
    "vrf-link": "/address/" + openVRF, "staking-link": "/address/" + staking,
    "vault-link": "/address/" + vault, "launch-link": "/tx/" + launch, "router-link": "/address/" + router,
    "draw-request-link": "/tx/" + dailyDrawRequest, "draw-payment-link": "/tx/" + dailyDrawPayout,
    "hourly-setup-link": "/tx/" + hourlySetup, "hourly-payment-link": "/tx/" + hourlyPayout,
    "staking-deposit-link": "/tx/" + stakingDeposit,
    "staking-ticket-claim-link": "/tx/" + stakingTicketClaim,
    "staking-ticket-link": "/token/" + tickets + "/instance/" + stakingTicket,
    "staking-yield-link": "/tx/" + stakingYieldClaim
  })) document.getElementById(id).href = explorer + route;
  document.querySelector("#proof").hidden = false;
}
async function showPools() {
  const manifest = await fetch("deployment.json", {cache: "no-store"});
  if (!manifest.ok) throw new Error("Deployment information is unavailable.");
  const config = await manifest.json();
  if (config.chainId !== 46630) throw new Error("Invalid testnet configuration.");
  if (config.hook === null) {
    status.textContent = "Waiting for the IRL testnet deployment.";
    return;
  }
  const {hook, staking} = config;
  if (!isAddress(hook) || !isAddress(staking)) throw new Error("Invalid testnet contract addresses.");
  showProof(config);
  if (BigInt(await read("eth_chainId")) !== 46630n) throw new Error("Unexpected testnet network.");
  const block = await read("eth_blockNumber");
  const selectors = {
    daily: "0x770b1036", weekly: "0xca0bf0cc", hourly: "0xba27ad89",
    protocol: "0x545475d4", buyback: "0x39a704dc"
  };
  const values = await Promise.all([
    ...Object.entries(selectors).map(async ([id, data]) =>
      [id, formatEther(await read("eth_call", [{to: hook, data}, block]))]),
    read("eth_getBalance", [staking, block]).then(value => ["staking", formatEther(value)])
  ]);
  for (const [id, value] of values) document.getElementById(id).textContent = value;
  status.textContent = "Live balances at Robinhood Chain Testnet block " + BigInt(block) + ".";
}
showPools().catch(error => { status.textContent = "Live balances unavailable. " + error.message; });
