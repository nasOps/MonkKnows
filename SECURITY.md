# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in MonkKnows, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email us at **keamonk@stud.kea.dk** with details of the vulnerability
3. Include steps to reproduce the issue if possible
4. We will acknowledge receipt within 48 hours

## Security Measures

- Passwords are hashed with bcrypt
- Session cookies are httponly and samesite=strict
- HTTPS enforced via nginx with HSTS
- Security scanning via Trivy, Brakeman, and Bundler Audit in CI
- OWASP ZAP baseline scanning in CF pipeline
