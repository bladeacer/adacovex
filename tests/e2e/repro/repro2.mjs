import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8099/');
await page.click('[data-tab="deps"]');
await page.waitForTimeout(200);
console.log('initial open:', await page.locator('.dep-node details[open]').count());
console.log('initial visible:', await page.locator('.dep-node:visible').count());
// uncheck dev
await page.click('label.cb:has-text("dev")');
await page.waitForTimeout(300);
console.log('after uncheck dev visible:', await page.locator('.dep-node:visible').count());
console.log('after uncheck dev open:', await page.locator('.dep-node details[open]').count());
// re-check dev
await page.click('label.cb:has-text("dev")');
await page.waitForTimeout(300);
console.log('after recheck dev visible:', await page.locator('.dep-node:visible').count());
console.log('after recheck dev open:', await page.locator('.dep-node details[open]').count());
// Now: expand root, then filter
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('root expanded? open:', await page.locator('.dep-node details[open]').count());
// filter by text: type "nomnoml" in dep-filter
await page.fill('#dep-filter', 'nomnoml');
await page.waitForTimeout(300);
console.log('after filter text visible:', await page.locator('.dep-node:visible').count());
console.log('after filter text open:', await page.locator('.dep-node details[open]').count());
// clear filter
await page.fill('#dep-filter', '');
await page.waitForTimeout(300);
console.log('after clear filter visible:', await page.locator('.dep-node:visible').count());
console.log('after clear filter open:', await page.locator('.dep-node details[open]').count());
// try expanding root again
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('after expanding root again, open:', await page.locator('.dep-node details[open]').count());
await browser.close();
