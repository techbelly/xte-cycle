// Renders site/index.html at the panel's exact size to site/frame.png.
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const page_url = "file://" + path.join(here, "site", "index.html");
const out = path.join(here, "site", "frame.png");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 792, height: 528 }, deviceScaleFactor: 1 });
page.on("pageerror", (e) => { console.error("page error:", e.message); process.exitCode = 1; });
await page.goto(page_url);
await page.evaluate(() => document.fonts.ready);
await page.screenshot({ path: out, type: "png" });
await browser.close();
console.log("Wrote", out);
