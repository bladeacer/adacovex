import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:8098/');
await page.click('[data-tab="deps"]');
await page.waitForTimeout(300);
console.log('initial open:', await page.locator('.dep-node details[open]').count());
console.log('initial visible:', await page.locator('.dep-node:visible').count());
// UNCHECK transitive = the root's own scope -> entire tree should disappear
await page.click('label.cb:has-text("transitive")');
await page.waitForTimeout(300);
console.log('after uncheck transitive, visible:', await page.locator('.dep-node:visible').count());
console.log('after uncheck transitive, open:', await page.locator('.dep-node details[open]').count());
// RE-check transitive
await page.click('label.cb:has-text("transitive")');
await page.waitForTimeout(300);
console.log('after recheck transitive, visible:', await page.locator('.dep-node:visible').count());
console.log('after recheck transitive, open:', await page.locator('.dep-node details[open]').count());
// Can we expand?
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('after click summary, open:', await page.locator('.dep-node details[open]').count());
console.log('after click summary, visible:', await page.locator('.dep-node:visible').count());
await browser.close();
