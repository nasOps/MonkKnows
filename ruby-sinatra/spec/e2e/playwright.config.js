const { defineConfig } = require('@playwright/test');

// Configuration for Playwrigt tests
module.exports = defineConfig({
    testDir: './tests',
    use: {
        baseURL: 'http://localhost:4567', // All tests will use this as the base URL
    },
});