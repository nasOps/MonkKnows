# Tools

## CI — Continuous Integration

| Tool | What it measures |
|---|---|
| **RuboCop** | Code style and complexity (including metrics cops) |
| **Brakeman** | Static security analysis of Ruby code |
| **Bundler Audit** | Known vulnerabilities in gem dependencies |
| **Hadolint** | Dockerfile best practices |
| **SonarCloud** | Code quality, duplication, complexity, and security |
| **RSpec** | Unit and integration tests |
| **Playwright** | End-to-end tests |

## CF — Continuous Feedback

| Tool | What it measures |
|---|---|
| **OWASP ZAP** | Dynamic security scanning of the running application |

## CD — Continuous Delivery & Deployment

| Tool | What it does |
|---|---|
| **Docker Buildx** | Builds the Docker image |
| **Trivy** | Scans the Docker image for vulnerabilities |
| **GHCR** | Stores and distributes the Docker image |
| **SSH** | Deploys the image to the production server |
| **Smoke Test** | Verifies the production URL is healthy after deployment |
