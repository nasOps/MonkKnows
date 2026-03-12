# Problems in Legacy Codebase – WhoKnows (Flask/Python)

Problems are sorted by priority. Critical issues appear first.

---

## Priority 1: Critical Security

### 1.1 SQL Injection (6 instances)
`app.py` uses Python string formatting to build SQL queries, making the app vulnerable to SQL injection attacks. Affected functions: `get_user_id()`, `before_request()`, `search()`, `api_search()`, `api_login()`, and `api_register()`.

**Example:**
```python
# Vulnerable
g.db.execute("SELECT * FROM users WHERE username = '%s'" % username)

# Fixed (parameterized query)
g.db.execute("SELECT * FROM users WHERE username = ?", (username,))
```

**Mitigation in Sinatra:** ActiveRecord uses parameterized queries by default (`User.find_by(username: ...)`, `Page.where('content LIKE ?', ...)`).

---

### 1.2 Weak Password Hashing (MD5)
`app.py` hashes passwords with MD5, which has been cryptographically broken since 2004. No salt is used, making identical passwords produce identical hashes and enabling rainbow table attacks.

**Mitigation in Sinatra:** Passwords are hashed with `bcrypt` via ActiveRecord's `has_secure_password`.

---

### 1.3 Hardcoded Secret Key
`app.py` sets `SECRET_KEY = 'development key'` directly in source code. The secret key signs session cookies, so a known key allows an attacker to forge sessions and impersonate any user.

**Mitigation in Sinatra:** Secret is loaded from an environment variable via `dotenv`: `ENV.fetch('SESSION_SECRET')`.

---

### 1.4 Default Admin Password
`schema.sql` inserts a default admin user with the password `"password"` (MD5-hashed), and the comment in the file explicitly states this. Any attacker reading the source code can immediately log in as admin.

**Mitigation in Sinatra:** No default users are seeded in the schema.

---

## Priority 2: Medium Security

### 2.1 Logout via GET Request
`/api/logout` accepts GET requests. GET requests can be triggered silently via `<img>` tags on third-party sites, enabling CSRF logout attacks.

**Mitigation in Sinatra:** Logout is handled via a JavaScript `fetch()` call to `/api/logout` as a deliberate user action.

### 2.2 No CSRF Protection
Forms in `login.html` and `register.html` submit directly via POST with no CSRF tokens, making the app vulnerable to cross-site request forgery.

**Mitigation in Sinatra:** Forms submit via `fetch()` to API endpoints, decoupling them from direct form POST exploitation.

### 2.3 Weak Email Validation
Registration only checks for presence of `@` in the email field. Values like `@` or `@@` pass validation.

**Mitigation in Sinatra:** ActiveRecord model validation uses a regex pattern for email format.

### 2.4 No Password Requirements
The only password validation is that the field is non-empty. Single-character passwords are accepted.

**Mitigation in Sinatra:** Model validation enforces a minimum password length.

---

## Priority 3: Code Quality

### 3.1 Hardcoded Database Path
`DATABASE_PATH = '../whoknows.db'` is hardcoded. Should be an environment variable.

### 3.2 Unused Import
`from datetime import datetime` is imported in `app.py` but never used.

### 3.3 Unused Variable
`PER_PAGE = 30` is defined but never used – no pagination is implemented.

### 3.4 Test Reference Error
`app_tests.py` sets `app.DATABASE` but `app.py` defines `DATABASE_PATH`. Tests reference a non-existent attribute.

### 3.5 Empty Test Method
`test_search()` in `app_tests.py` contains only `pass` – the test is not implemented.

### 3.6 Deprecated `unlink()` Usage
`tearDown()` calls `self.db.unlink(self.db.name)` on a file object. The correct approach is `os.unlink()`.

---

## Priority 4: HTML & Styling

### 4.1 Missing HTML Structure
`layout.html` lacks `<html>`, `<head>`, and `<body>` tags, as well as `<meta charset="utf-8">` and a viewport meta tag for responsive design.

**Mitigation in Sinatra:** `layout.erb` has a complete, valid HTML5 structure with all required tags.

### 4.2 Character Encoding Error
`¿` renders as `Â¿` throughout `layout.html` due to missing charset declaration.

**Mitigation in Sinatra:** Fixed by adding `<meta charset="UTF-8">` and saving templates as UTF-8.

### 4.3 Unclosed HTML Tags
`<li>`, `<dt>`, and `<dd>` tags in `layout.html`, `login.html`, and `register.html` are never closed, producing invalid HTML.

**Mitigation in Sinatra:** All tags are properly closed in the ERB templates.

### 4.4 Inline JavaScript Event Handlers
`search.html` uses `onclick="..."` inline attributes. Best practice is to use `addEventListener` in a separate script block.

**Mitigation in Sinatra:** `index.erb` uses `document.addEventListener` and no inline event handlers.