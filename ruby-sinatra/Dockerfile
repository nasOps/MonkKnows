# ---- Stage 1: Build ----
FROM ruby:3.2-slim AS build

ARG BUNDLE_WITHOUT="development test"

# Install only essential build dependencies, delete list after installation to reduce image size
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile first (for layer caching)
COPY Gemfile Gemfile.lock ./

# Install runtime gems only
RUN bundle config set without "$BUNDLE_WITHOUT" \
 && bundle install

# Copy application code
COPY . .

# ---- Stage 2: Runtime ----
FROM ruby:3.2-slim

# Install only essential runtime dependencies, delete list after installation to reduce image size
RUN apt-get update -qq && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gems and app from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Run as non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 4567

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ruby -e "require 'net/http'; res = Net::HTTP.get_response(URI('http://localhost:4567/health')); exit(res.is_a?(Net::HTTPSuccess) ? 0 : 1)" || exit 1

# Starts Ruby and runs app.rb when the container launches
CMD ["ruby", "app.rb"]