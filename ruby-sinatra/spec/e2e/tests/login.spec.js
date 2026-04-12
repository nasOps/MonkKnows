const { test, expect, request } = require('@playwright/test');
const { uniqueUser } = require('./helpers');

// Login - GET "/login" → fill form → POST "/api/login" via JS fetch → redirect to "/"
// User is created via API before the test — setup should not be what is tested

test('existing user can login', async ({ page }) => {
    const user = uniqueUser();

    // Register a new user via API to be independent of DB state
    const ctx = await request.newContext({ baseURL: 'http://localhost:4567' });
    await ctx.post('/api/register', {
        data: { ...user, password2: user.password }
    });
    // Fail fast if setup fails — otherwise login test fails for the wrong reason
    expect(setupResponse.ok()).toBeTruthy();

    // Go to the login page
    await page.goto('/login');

    // Fill out the form — name attributes match login.erb exactly
    await page.fill('input[name="username"]', user.username);
    await page.fill('input[name="password"]', user.password);

    // Submit — login.erb uses input[type="submit"], not a button element
    await page.click('input[type="submit"]');

    // JS fetch handles POST to /api/login, then sets window.location.href = '/'
    await page.waitForURL('http://localhost:4567/');
    expect(page.url()).toBe('http://localhost:4567/');
});