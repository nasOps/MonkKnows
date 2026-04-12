// Generates a unique user based on timestamp
// Prevents username conflicts since SQLite persists between test runs
function uniqueUser() {
    const ts = Date.now();
    return {
        username: `testuser_${ts}`,
        email:    `test_${ts}@test.com`,
        password: 'Test1234',
    };
}

module.exports = { uniqueUser };