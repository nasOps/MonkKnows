const { test, expect } = require('@playwright/test');
const { uniqueUser } = require('./helpers');

// Registration - GET "/register" → fill form → POST "/api/register" via JS fetch → redirect to "/"
// Note: form uses e.preventDefault() and fetch — waitForURL waits for JS navigation

test('new user is able to register', async ({ page }) => {
    const user = uniqueUser();

    // Go to the registration page
    await page.goto('/register');

    // Fill out the form — name attributes match register.erb exactly
    await page.fill('input[name="username"]', user.username);
    await page.fill('input[name="email"]',    user.email);
    await page.fill('input[name="password"]', user.password);
    await page.fill('input[name="password2"]', user.password);

    // Submit — register.erb uses input[type="submit"], not a button element
    await page.evaluate(() => {
        document.getElementById('register-form').dispatchEvent(new Event('submit'));
    });

    // JS fetch handles POST to /api/register, then sets window.location.href = '/'
    // waitForURL waits for JS navigation to complete (toHaveURL would fail too early)
    await page.waitForURL('http://localhost:4567/');
    expect(page.url()).toBe('http://localhost:4567/');
});