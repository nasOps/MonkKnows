const { test, expect } = require('@playwright/test');

//  GET /search
test('search returns page with no errors', async ({ page }) => {
    await page.goto('/');

    // name="q" is the search input field, we fill it with "test" and submit the form
    await page.fill('input[name="q"]', 'test');
    await page.click('button[type="submit"]');

    // URL must include search query parameter "q=test"
    await expect(page).toHaveURL(/\?q=test/);

    // Page must show results for "test" or "No results found" - not an error
    const hasResults = await page.locator('#results').isVisible();
    const hasNoResults = await page.locator('.no-results').isVisible();
    expect(hasResults || hasNoResults).toBeTruthy();
});

