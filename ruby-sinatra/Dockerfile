# ---- Stage 1: Build ----
FROM ruby:3.2-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base sqlite-dev

WORKDIR /app

# Copy Gemfile first (for layer caching)
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set without 'development test' \
 && bundle install

# Copy application code
COPY . .

# ---- Stage 2: Runtime ----
FROM ruby:3.2-alpine

# Install only runtime dependencies
RUN apk add --no-cache sqlite-libs

WORKDIR /app

# Copy gems and app from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

EXPOSE 4567

CMD ["ruby", "app.rb"]