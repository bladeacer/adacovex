import { chromium } from '@playwright/test';

const BASE = 'http://localhost:8123';
const OUT = '/tmp/opencode/shots';

import { mkdirSync } from 'fs';
mkdirSync(OUT, { recursive: true });

const tabs = ['overview', 'proof', 'charts', 'api', 'compliance', 'deps', 'tests', 'credits'];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });

await page.goto(`${BASE}/?theme=light`, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('[data-tab="charts"]', { timeout: 15000 });
await page.evaluate(() => localStorage.removeItem('adacovex-tab'));

const problems = [];
page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') problems.push(`console: ${m.text()}`); });

for (const tab of tabs) {
  await page.click(`[data-tab="${tab}"]`);
  await page.waitForSelector(`#tab-${tab}`, { state: 'visible', timeout: 15000 });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${OUT}/${tab}.png`, fullPage: true });
  console.log(`captured ${tab}`);
}

// Sanity probes on the proof tab: every donut must be a bounded 200px ring.
await page.click('[data-tab="proof"]');
await page.waitForSelector('#tab-proof', { state: 'visible' });
const sizes = await page.evaluate(() => {
  const out = [];
  document.querySelectorAll('.donut').forEach((d) => {
    const r = d.getBoundingClientRect();
    out.push({ cls: 'donut', w: Math.round(r.width), h: Math.round(r.height) });
  });
  document.querySelectorAll('.donut-center').forEach((d) => {
    const r = d.getBoundingClientRect();
    out.push({ cls: 'center', w: Math.round(r.width), h: Math.round(r.height) });
  });
  // Any element wider than the viewport is a layout overflow.
  document.querySelectorAll('#tab-proof *').forEach((el) => {
    const r = el.getBoundingClientRect();
    if (r.width > 1600) out.push({ cls: `OVERFLOW ${el.className || el.tagName}`, w: Math.round(r.width) });
  });
  return out;
});
console.log(JSON.stringify(sizes, null, 1));
if (problems.length) console.log('PROBLEMS:', problems.join('\n'));

await browser.close();
