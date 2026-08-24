import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8098/');
await page.click('[data-tab="deps"]');
await page.waitForTimeout(300);
console.log('initial open:', await page.locator('.dep-node details[open]').count());
console.log('initial visible:', await page.locator('.dep-node:visible').count());
// Click the root (crdt) summary: initially open -> close it
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('after collapsing root, open:', await page.locator('.dep-node details[open]').count());
// Now click filter checkbox "dev" (uncheck)
await page.click('label.cb:has-text("dev")');
await page.waitForTimeout(300);
console.log('after uncheck dev, open:', await page.locator('.dep-node details[open]').count());
console.log('after uncheck dev, visible:', await page.locator('.dep-node:visible').count());
// click root summary to expand — DOES IT WORK?
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('after clicking root summary, open:', await page.locator('.dep-node details[open]').count());
console.log('after clicking root summary, visible:', await page.locator('.dep-node:visible').count());
await browser.close();
