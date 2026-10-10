import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8099/');
await page.click('[data-tab="deps"]');
const opened = await page.locator('.dep-node details[open]').count();
console.log('open details initially:', opened);
console.log('total nodes:', await page.locator('.dep-node').count());
// Click the "base" label text (the checkbox input is visually hidden)
await page.click('label.cb:has-text("base")');
await page.waitForTimeout(300);
const opened2 = await page.locator('.dep-node details[open]').count();
console.log('open details after unchecking base:', opened2);
const visibleNodes = await page.locator('.dep-node:visible').count();
console.log('visible nodes after uncheck base:', visibleNodes);
// re-check
await page.click('label.cb:has-text("base")');
await page.waitForTimeout(300);
const opened3 = await page.locator('.dep-node details[open]').count();
console.log('open details after re-checking base:', opened3);
console.log('visible nodes after re-check:', await page.locator('.dep-node:visible').count());
// Try to open the root details by clicking its summary (should already be open)
const sum = page.locator('.dep-node details summary').first();
await sum.click();
await page.waitForTimeout(200);
console.log('after clicking first summary, open details:', await page.locator('.dep-node details[open]').count());
// Now scroll into view and check the details inside
const d = page.locator('.dep-node details').first();
console.log('first details open attr:', await d.getAttribute('open'));
await browser.close();
