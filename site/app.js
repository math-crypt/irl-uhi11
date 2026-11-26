const status = document.querySelector("#status");
const rpc = "https://rpc.testnet.chain.robinhood.com";

async function read(method, params = []) {
  const response = await fetch(rpc, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({jsonrpc: "2.0", id: 1, method, params})
  });
  if (!response.ok) throw new Error("The testnet is unavailable.");
  const message = await response.json();
  if (message.error || typeof message.result !== "string") throw new Error("The testnet read failed.");
  return message.result;
}

function formatEther(word) {
  if (!/^0x[0-9a-f]{64}$/i.test(word)) throw new Error("Unexpected prize pool response.");
  const digits = BigInt(word).toString().padStart(19, "0");
  const fraction = digits.slice(-18).replace(/0+$/, "");
  return digits.slice(0, -18) + (fraction ? "." + fraction : "") + " ETH";
}

async function showPools() {
  const manifest = await fetch("deployment.json", {cache: "no-store"});
  if (!manifest.ok) throw new Error("Deployment information is unavailable.");
  const {chainId, hook} = await manifest.json();
  if (chainId !== 46630) throw new Error("Invalid testnet configuration.");
  if (hook === null) {
    status.textContent = "Waiting for the IRL testnet deployment.";
    return;
  }
  if (!/^0x[0-9a-f]{40}$/i.test(hook) || BigInt(await read("eth_chainId")) !== 46630n)
    throw new Error("Check the testnet deployment configuration.");
  const block = await read("eth_blockNumber");
  const selectors = ["0x770b1036", "0xca0bf0cc"]; // dailyLotteryPot(), sundayMegaPot()
  const [daily, weekly] = await Promise.all(selectors.map(async data =>
    formatEther(await read("eth_call", [{to: hook, data}, block]))));
  document.querySelector("#daily").textContent = daily;
  document.querySelector("#weekly").textContent = weekly;
  status.textContent = "Verified at Robinhood Chain Testnet block " + BigInt(block) + ".";
}
showPools().catch(error => { status.textContent = error.message; });
