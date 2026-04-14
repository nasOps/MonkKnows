const { test, expect } = require('@playwright/test');

// Smoke tests — verifies the app is running and key pages are accessible
// These run first and fail fast if the app is down

test('frontpage loads with status 200', async ({ page }) => {
    const response = await page.goto('/');
    expect(response.status()).toBe(200);
});

test('login page is accessible', async ({ page }) => {
    await page.goto('/login');
    await expect(page).toHaveTitle(/monkknows/i);
});