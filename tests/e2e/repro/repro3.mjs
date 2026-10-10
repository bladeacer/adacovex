import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8099/');
await page.click('[data-tab="deps"]');
await page.waitForTimeout(200);
// expand root manually first (it's open initially)
console.log('A) open:', await page.locator('.dep-node details[open]').count());
console.log('A) visible:', await page.locator('.dep-node:visible').count());
// uncheck vendored (hides 7 children)
await page.click('label.cb:has-text("vendored")');
await page.waitForTimeout(300);
console.log('B) after uncheck vendored visible:', await page.locator('.dep-node:visible').count());
console.log('B) open:', await page.locator('.dep-node details[open]').count());
// recheck vendored
await page.click('label.cb:has-text("vendored")');
await page.waitForTimeout(300);
console.log('C) after recheck visible:', await page.locator('.dep-node:visible').count());
console.log('C) open:', await page.locator('.dep-node details[open]').count());
// Now click the root summary to COLLAPSE it, then try to RE-EXPAND
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('D) after clicking summary (expect 0):', await page.locator('.dep-node details[open]').count());
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('E) after clicking summary again (expect 1):', await page.locator('.dep-node details[open]').count());
// Now uncheck/recheck with collapsed root, then click root summary to expand
await page.click('label.cb:has-text("vendored")');
await page.waitForTimeout(200);
await page.click('label.cb:has-text("vendored")');
await page.waitForTimeout(200);
console.log('F) after filter with collapsed root, open:', await page.locator('.dep-node details[open]').count());
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('G) after clicking summary, open:', await page.locator('.dep-node details[open]').count());
console.log('G) visible:', await page.locator('.dep-node:visible').count());
await browser.close();
