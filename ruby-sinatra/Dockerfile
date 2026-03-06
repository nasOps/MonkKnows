# ---- Stage 1: Build ----
FROM ruby:3.2-slim AS build

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libsqlite3-dev

WORKDIR /app

# Copy Gemfile first (for layer caching)
COPY Gemfile Gemfile.lock ./

# Install runtime gems only
RUN bundle config set without 'development test' \
 && bundle install

# Copy application code
COPY . .

# ---- Stage 2: Runtime ----
FROM ruby:3.2-slim

# Install only runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y libsqlite3-0

WORKDIR /app

# Copy gems and app from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 4567

# Starts Ruby and runs app.rb when the container launches
CMD ["ruby", "app.rb"]