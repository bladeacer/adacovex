import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  // The dashboard server is a single process with a 4-worker task pool;
  // a fully-parallel browser swarm overloads it (goto timeouts), and the
  // suite is one file anyway, so run serially.
  workers: 1,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:8080',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'python3 start-server.py',
    url: 'http://localhost:8080',
    reuseExistingServer: !process.env.CI,
  },
});
