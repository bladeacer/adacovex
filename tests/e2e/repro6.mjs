import { chromium } from '@playwright/test';
const browser = await chromium.launch();
const page = await browser.newPage();
const errors = [];
page.on('pageerror', e => errors.push('PAGEERROR: ' + e.message));
page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });
await page.goto('http://localhost:8098/');
await page.click('[data-tab="deps"]');
await page.waitForTimeout(300);
// Switch to nomnoml view
await page.click('[data-view="nomnoml"]');
await page.waitForTimeout(500);
console.log('nomnoml view errors so far:', errors.length ? errors : 'none');
// Now click a filter checkbox (uncheck dev) while in nomnoml view
await page.click('label.cb:has-text("dev")');
await page.waitForTimeout(500);
console.log('after filter in nomnoml, errors:', errors.length ? errors : 'none');
// Switch back to tree view
await page.click('[data-view="tree"]');
await page.waitForTimeout(300);
console.log('tree visible after switching back:', await page.locator('.dep-node:visible').count());
// Try expanding
await page.locator('.dep-node details summary').first().click();
await page.waitForTimeout(200);
console.log('after click, open:', await page.locator('.dep-node details[open]').count());
console.log('all errors:', errors);
await browser.close();
