import { chromium } from '@playwright/test';

const BASE = 'http://localhost:8080';
const OUT = '/home/data/Desktop/projects/adacovex/docs/media';

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });

// Force light theme via query param (stable, deterministic screenshots).
await page.goto(`${BASE}/?theme=light`, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('[data-tab="charts"]', { timeout: 15000 });
// Reset any persisted tab so the capture starts from the Overview.
await page.evaluate(() => localStorage.removeItem('adacovex-tab'));

async function capture(tab, file) {
  await page.click(`[data-tab="${tab}"]`);
  await page.waitForSelector(`#tab-${tab}`, { state: 'visible', timeout: 15000 });
  // Give charts / the API playground (which runs /api/metrics on open) time.
  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${OUT}/${file}`, fullPage: true });
  console.log(`captured ${file}`);
}

await capture('charts', 'dashboard_preview_charts.png');
await capture('api', 'dashboard_preview_api.png');

await browser.close();
console.log('done');
