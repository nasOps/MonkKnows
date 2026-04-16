#!/bin/bash
# Installs git pre-commit hook for the project
# Run once: bash scripts/install-hooks.sh

HOOK_DIR="$(git rev-parse --show-toplevel)/.git/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

cat > "$HOOK_FILE" << 'HOOK'
#!/bin/bash
# Pre-commit hook: runs RuboCop on staged Ruby files

STAGED_RB=$(git diff --cached --name-only --diff-filter=ACM | grep '\.rb$')

if [ -z "$STAGED_RB" ]; then
  exit 0
fi

echo "Running RuboCop on staged files..."

# Convert host paths to container paths (ruby-sinatra/ -> /app/)
CONTAINER_FILES=$(echo "$STAGED_RB" | sed 's|^ruby-sinatra/||')

# Try Docker first (matches CI environment), fall back to local bundle
if docker compose -f docker-compose.dev.yml ps --status running web 2>/dev/null | grep -q web; then
  echo "$CONTAINER_FILES" | xargs docker compose -f docker-compose.dev.yml exec -T web bundle exec rubocop --force-exclusion
  RESULT=$?
elif cd ruby-sinatra 2>/dev/null; then
  echo "$CONTAINER_FILES" | xargs bundle exec rubocop --force-exclusion
  RESULT=$?
else
  echo "⚠️  Skipping RuboCop — Docker not running and rubocop not installed locally"
  exit 0
fi

if [ $RESULT -eq 0 ]; then
  echo "✅ RuboCop passed"
else
  echo "❌ RuboCop failed — fix offenses before committing"
  exit 1
fi
HOOK

chmod +x "$HOOK_FILE"
echo "✅ Pre-commit hook installed at $HOOK_FILE"
