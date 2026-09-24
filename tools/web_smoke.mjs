// Boot the web build in a headless Chrome (started with --remote-debugging-port=9222), go
// title -> a circuit (default 1) -> race, and write the browser console and two screenshots.
//   node tools/web_smoke.mjs http://127.0.0.1:8060/index.html <out dir> [circuit 1-4]
import { writeFileSync } from "node:fs";
const [, , url, outDir, circuit = "1"] = process.argv;
const sleep = ms => new Promise(r => setTimeout(r, ms));
let targets = [];
for (let i = 0; i < 40 && !targets.length; i++) {
  try { targets = (await (await fetch("http://127.0.0.1:9222/json")).json()).filter(t => t.type === "page"); } catch {}
  if (!targets.length) await sleep(500);
}
const ws = new WebSocket(targets[0].webSocketDebuggerUrl);
await new Promise(r => (ws.onopen = r));
let id = 0; const pending = new Map(); const log = [];
ws.onmessage = e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled") log.push(`[${m.params.type}] ` + m.params.args.map(a => a.value ?? a.description ?? "").join(" "));
  if (m.method === "Runtime.exceptionThrown") log.push("[EXCEPTION] " + (m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text));
};
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send("Runtime.enable"); await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await send("Page.navigate", { url });
const shot = async name => { const r = await send("Page.captureScreenshot", { format: "png" }); writeFileSync(`${outDir}/${name}.png`, Buffer.from(r.data, "base64")); };
const key = async (k, code, vk) => {
  await send("Input.dispatchKeyEvent", { type: "keyDown", key: k, code, windowsVirtualKeyCode: vk, text: k.length === 1 ? k : undefined });
  await sleep(80);
  await send("Input.dispatchKeyEvent", { type: "keyUp", key: k, code, windowsVirtualKeyCode: vk });
};
await sleep(45000); await shot("1_title");
await send("Input.dispatchMouseEvent", { type: "mousePressed", x: 640, y: 360, button: "left", clickCount: 1 });
await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 640, y: 360, button: "left", clickCount: 1 });
await sleep(500); await key("Enter", "Enter", 13); await sleep(3000);
await key(circuit, `Digit${circuit}`, 48 + Number(circuit)); await sleep(40000); await shot("2_race");
writeFileSync(`${outDir}/console.txt`, log.join("\n") + "\n");
ws.close(); process.exit(0);
