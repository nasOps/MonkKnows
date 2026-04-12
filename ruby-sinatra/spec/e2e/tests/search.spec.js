const { test, expect, request } = require('@playwright/test');

// Helper method:
// Generates a unique user object with a timestamp to ensure uniqueness even when the same name is used multiple times
function uniqueUser() {
    const ts = Date.now();
    return {
        username: `testuser_${ts}`,
        email:    `test_${ts}@test.com`,
        password: 'Test1234',
    };
}

// --- Frontpage

// GET
test('frontpage loads with status 200', async ({ page }) => {
    const response = await page.goto('/'); // Navigate to the front page
    expect(response.status()).toBe(200); // Assert that the response status is 200
});

// --- Login page

// GET
test('login page is accessible', async ({ page }) => {
    await page.goto('/login'); // Navigate to the login page
    await expect(page).toHaveTitle(/whoknows/i); // Assert that the page title contains "whoknows"
});

// --- Registration

//  GET form "/register", POST registration "/api/register", redirect to frontpage "/"
// Note: form uses JavaScript fetch (e.preventDefault) — waitForURL waits for JS navigation
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
    await page.click('input[type="submit"]');

    // JS fetch handles POST to /api/register, then sets window.location.href = '/'
    // waitForURL waits for JS navigation to complete (toHaveURL would fail too early)
    await page.waitForURL('http://localhost:4567/');
    expect(page.url()).toBe('http://localhost:4567/');
});

// --- Login

// GET "/login", POST "/api/login" and redirect to frontpage "/"
// Note: form uses JavaScript fetch (e.preventDefault) — waitForURL waits for JS navigation
test('existing user can login', async ({ page }) => {
    const user = uniqueUser();

    // Register a new user via API to be independent of DB state
    const ctx = await request.newContext({ baseURL: 'http://localhost:4567' });
    await ctx.post('/api/register', {
        data: { ...user, password2: user.password }
    });

    // Go to the login page
    await page.goto('/login');

    // Fill out the form — name attributes match login.erb exactly
    await page.fill('input[name="username"]', user.username);
    await page.fill('input[name="password"]', user.password);

    // Submit — login.erb uses input[type="submit"], not a button element
    await page.click('input[type="submit"]');

    // JS fetch handles POST to /api/login, then sets window.location.href = '/'
    // waitForURL waits for JS navigation to complete
    await page.waitForURL('http://localhost:4567/');
    expect(page.url()).toBe('http://localhost:4567/');
});

// --- Search

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

