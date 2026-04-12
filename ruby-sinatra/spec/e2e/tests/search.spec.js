const { test, expect } = require('@playwright/test');

test('frontpage loads with status 200', async ({ page }) => {
    const response = await page.goto('/'); // Navigate to the front page
    expect(response.status()).toBe(200); // Assert that the response status is 200
});

test('login page is accessible', async ({ page }) => {
    await page.goto('/login'); // Navigate to the login page
    await expect(page).toHaveTitle(/whoknows/i); // Assert that the page title contains "whoknows"
});