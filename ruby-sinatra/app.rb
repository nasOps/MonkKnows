# frozen_string_literal: true

# = Less memory usage by freezing string literals

# Main application file - Routes + Controllers (combined)
require 'sinatra'
require 'json'
require 'digest'
require_relative 'config/environment'
require_relative 'models/page'
require_relative 'models/user'
require_relative 'models/user_activity_log'
require_relative 'models/exception_log'
require_relative 'services/weather_service'
require_relative 'models/search_log'
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'
require 'prometheus/client'

class WhoknowsApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  # Sinatra configuration
  set :database_file, File.expand_path('config/database.yml', __dir__)
  set :public_folder, File.expand_path('public', __dir__)
  set :views, File.expand_path('views', __dir__)
  set :bind, '0.0.0.0'
  set :logging, true

  # Prometheus custom metrics
  PROMETHEUS = Prometheus::Client.registry
  USERS_TOTAL = PROMETHEUS.gauge(
    :app_users_total,
    docstring: 'Total number of registered users',
    labels: []
  )
  SEARCHES_TOTAL = PROMETHEUS.counter(
    :app_searches_total,
    docstring: 'Total number of search queries',
    labels: []
  )
  SEARCH_ZERO_RESULTS = PROMETHEUS.counter(
    :app_search_zero_results_total,
    docstring: 'Total number of searches that returned no results',
    labels: []
  )
  SEARCH_RESULT_COUNT = PROMETHEUS.histogram(
    :app_search_result_count,
    docstring: 'Distribution of result counts returned by searches',
    labels: [],
    buckets: [0, 1, 2, 5, 10, 20, 50, 100]
  )
  ACTIVE_USERS_1D = PROMETHEUS.gauge(
    :app_active_users_1d, docstring: 'Distinct users active in the last 24h (DAU)', labels: []
  )
  ACTIVE_USERS_7D = PROMETHEUS.gauge(
    :app_active_users_7d, docstring: 'Distinct users active in the last 7 days (WAU)', labels: []
  )
  ACTIVE_USERS_30D = PROMETHEUS.gauge(
    :app_active_users_30d, docstring: 'Distinct users active in the last 30 days (MAU)', labels: []
  )
  EXCEPTIONS_TOTAL = PROMETHEUS.counter(
    :app_exceptions_total,
    docstring: 'Total number of unhandled exceptions, labeled by path and error class',
    labels: %i[path error_class]
  )
  RESPONSE_SIZE = PROMETHEUS.histogram(
    :app_response_size_bytes,
    docstring: 'Response body size in bytes, labeled by path',
    labels: [:path],
    buckets: [128, 512, 2_048, 8_192, 32_768, 131_072, 524_288, 2_097_152]
  )

  # In-memory throttle cache for user activity writes — at most one
  # user_activity_logs row per user per ACTIVITY_THROTTLE_SECONDS.
  ACTIVITY_THROTTLE = {} # rubocop:disable Style/MutableConstant
  ACTIVITY_THROTTLE_MUTEX = Mutex.new
  ACTIVITY_THROTTLE_SECONDS = 5 * 60

  # Allow-list of app routes — used to bound Prometheus label cardinality.
  # Anything outside this set (404 scanners, /wp-admin/*, /.env etc.) collapses
  # into 'other', so EXCEPTIONS_TOTAL{path=...} and RESPONSE_SIZE{path=...}
  # don't accumulate one series per scanner-path forever.
  KNOWN_PATHS = %w[
    / /api/search /api/login /api/register /api/logout /api/weather
    /health /hello /login /register /weather /logout /metrics
    /api/search-logs/top /api/pages
  ].freeze

  def self.normalize_path(path)
    KNOWN_PATHS.include?(path) ? path : 'other'
  end

  # Update gauges every 60 seconds in a background thread.
  # Lives outside Puma's request path so DB queries don't add request latency.
  unless ENV['RACK_ENV'] == 'test'
    Thread.new do
      loop do
        ActiveRecord::Base.connection_pool.with_connection do
          USERS_TOTAL.set(User.count)
          now = Time.now
          ACTIVE_USERS_1D.set(UserActivityLog.where('created_at > ?', now - 86_400).distinct.count(:user_id))
          ACTIVE_USERS_7D.set(UserActivityLog.where('created_at > ?', now - (7 * 86_400)).distinct.count(:user_id))
          ACTIVE_USERS_30D.set(UserActivityLog.where('created_at > ?', now - (30 * 86_400)).distinct.count(:user_id))
        end
      rescue StandardError => e
        warn "Prometheus gauge error: #{e.message}"
      ensure
        sleep 60
      end
    end
  end

  # Session configuration (needed for login/logout)
  set :session_secret,
      if ENV['RACK_ENV'] == 'production'
        ENV.fetch('SESSION_SECRET') { raise 'SESSION_SECRET must be set in production' }
      else
        ENV.fetch('SESSION_SECRET') { 'x' * 64 }
      end
  # To prevent CSRF attacks by not sending cookies on cross-site requests
  set :sessions,
      same_site: :strict,
      secure: ENV['RACK_ENV'] == 'production', # Only send cookies over HTTPS in production
      httponly: true # JS cannot read the cookie. Protects from XSS attacks stealing the session cookie

  # Test - no DB needed - http://localhost:4567/hello
  get '/hello' do
    'Sinatra says Hello World!'
  end

  get '/health' do
    status 200
    'ok'
  end

  ################################################################################
  # Before/After Request Handlers
  ################################################################################

  before do
    request.env['sinatra.route_start_time'] = Time.now
    @current_user = nil
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
    track_user_activity

    # Parse JSON body og merge ind i params
    # Begrænset til POST requests da GET aldrig sender JSON body
    next unless request.post? && request.content_type&.include?('application/json')

    request.body.rewind if request.body.respond_to?(:rewind)
    begin
      json_body = JSON.parse(request.body.read, symbolize_names: false)
      if json_body.is_a?(Hash)
        json_body.each { |k, v| params[k] ||= v }
      else
        content_type :json
        halt 400, { detail: [{ loc: ['body'], msg: 'Expected JSON object', type: 'type_error' }] }.to_json
      end
    rescue JSON::ParserError
      content_type :json
      halt 400, { detail: [{ loc: ['body'], msg: 'Invalid JSON', type: 'parse_error' }] }.to_json
    end
  end

  after do
    # Calcutes request duration in milliseconds with 2 decimal places
    duration = ((Time.now - request.env['sinatra.route_start_time']) * 1000).round(2)

    # Observe response size for every request (heavy endpoints become visible
    # in the dashboard's response_size p95 panel). response.content_length is
    # nil in after-hooks because Rack::Response#finish only sets Content-Length
    # after after-hooks run; compute it from body bytes instead.
    size = Array(response.body).sum { |chunk| chunk.to_s.bytesize }
    path_label = self.class.normalize_path(request.path_info)
    RESPONSE_SIZE.observe(size, labels: { path: path_label }) if size.positive?

    # Fetches the search query from params and normalizes it (nil if empty)
    query = params[:q].to_s.strip
    query = nil if query.empty?

    if query && ['/', '/api/search'].include?(request.path_info)
      SEARCH_RESULT_COUNT.observe(@result_count) if @result_count
      begin
        SearchLog.create(
          query: query,
          path: request.path_info,
          http_method: request.request_method,
          status: response.status,
          ip: Digest::SHA256.hexdigest("#{Date.today}#{request.ip}")[0..15],
          duration_ms: duration,
          result_count: @result_count
        )
      rescue StandardError => e
        logger.error("Failed to log search: #{e.message}")
      end
    end

    log_data = {
      timestamp: Time.now.utc.iso8601,
      method: request.request_method,
      path: request.path_info,
      status: response.status,
      ip: Digest::SHA256.hexdigest("#{Date.today}#{request.ip}")[0..15],
      user: session[:user_id] ? Digest::SHA256.hexdigest(session[:user_id].to_s)[0..7] : nil,
      duration_ms: ((Time.now - request.env['sinatra.route_start_time']) * 1000).round(2),
      query: (params[:q].strip if params[:q] && !params[:q].strip.empty?),
      user_agent: request.user_agent,
      referer: request.referer,
      response_size: response.content_length,
      result_count: @result_count,
      exception: @exception_class
    }.compact
    logger.info(log_data.to_json)
  end

  ################################################################################
  # HTML Routes (Page Routes)
  ################################################################################

  # GET / - Root/Search page - http://localhost:4567
  # OpenAPI: operationId "serve_root_page__get"
  get '/' do
    @q = params[:q]
    @language = params[:language] || 'en'

    @results = if @q && !@q.strip.empty?
                 SEARCHES_TOTAL.increment
                 results = Page.search(@q, language: @language)
                 SEARCH_ZERO_RESULTS.increment if results.empty?
                 results
               else
                 []
               end
    @result_count = @results.length if @q && !@q.strip.empty?

    erb :index
  end

  # GET /weather - Weather page
  # OpenAPI: operationId "serve_weather_page_weather_get"
  get '/weather' do
    content_type :html
    status 200
    @weather = begin
      WeatherService.fetch
    rescue StandardError => e
      logger.warn("WeatherService.fetch failed: #{e.message}")
      { city: 'Unknown', temperature: 0.0, condition: 'unknown', humidity: 0, wind_speed: 0 }
    end
    erb :weather
  end

  # GET /register - Registration page
  # OpenAPI: operationId "serve_register_page_register_get"
  # GET /register - viser registrerings-formularen
  get '/register' do
    redirect '/' if logged_in?

    erb :register, locals: { error: nil }
  end

  # GET /login - Login page
  # OpenAPI: operationId "serve_login_page_login_get"
  get '/login' do
    redirect '/' if logged_in?
    @error = nil
    erb :login
  end

  # /reset-password removed — force_password_reset column dropped in PostgreSQL migration

  ################################################################################
  # API Routes (JSON Responses)
  ###############################################################################

  # GET /api/search - Search API endpoint - http://localhost:4567/api/search?q=test
  # OpenAPI: operationId "search_api_search_get"
  get '/api/search' do
    content_type :json

    q = params[:q]
    language = params[:language] || 'en'

    if q.nil? || q.strip.empty?
      status 422
      {
        statusCode: 422,
        message: "Query parameter 'q' is required"
      }.to_json

    else
      SEARCHES_TOTAL.increment
      search_results = Page.search(q, language: language)
      SEARCH_ZERO_RESULTS.increment if search_results.empty?
      @result_count = search_results.length

      status 200
      {
        data: search_results.as_json(except: :tsv)
      }.to_json
    end
  end

  # GET /api/weather - Weather API endpoint
  # OpenAPI: operationId "weather_api_weather_get"
  get '/api/weather' do
    content_type :json

    begin
      weather_data = WeatherService.fetch

      status 200
      { data: weather_data }.to_json

      # Error handling below is not defined in the OpenAPI Spec
    rescue StandardError => e
      status 500
      {
        detail: [
          {
            loc: ['server'],
            msg: e.message,
            type: 'external_service_error'
          }
        ]
      }.to_json
    end
  end

  # POST /api/register - User registration
  # OpenAPI: operationId "register_api_register_post"
  post '/api/register' do
    content_type :json

    password  = params[:password]
    password2 = params[:password2]

    # Tjek password-match foerst (ikke en model-validation,
    # da password2 ikke er en kolonne i databasen)
    if password != password2
      status 422
      return {
        detail: [{ loc: %w[body password2], msg: 'The two passwords do not match', type: 'value_error' }]
      }.to_json
    end

    user = User.new(
      username: params[:username],
      email: params[:email],
      password: password || '',
      password_digest: User.hash_password(password || '')
    )

    if user.save
      session[:user_id] = user.id
      @current_user = user
      track_user_activity
      status 200
      { statusCode: 200, message: 'You were successfully registered' }.to_json
    else
      status 422
      { detail: [{ loc: ['body'], msg: user.errors.first&.message, type: 'value_error' }] }.to_json
    end
  end

  # POST /api/login - User login
  # OpenAPI: operationId "login_api_login_post"
  post '/api/login' do
    content_type :json

    user = User.find_by(username: params[:username])

    if user.nil?
      status 422
      return {
        detail: [{ loc: %w[body username], msg: 'Invalid username', type: 'value_error' }]
      }.to_json
    end

    unless user.verify_password?(params[:password])
      status 422
      return {
        detail: [{ loc: %w[body password], msg: 'Invalid password', type: 'value_error' }]
      }.to_json
    end

    session[:user_id] = user.id
    @current_user = user
    track_user_activity

    status 200
    { statusCode: 200, message: 'You were logged in' }.to_json
  end

  # /api/reset-password removed — force_password_reset column dropped in PostgreSQL migration

  # GET /api/search-logs/top - Top search terms (used by crawler)
  # OpenAPI: operationId "top_search_logs_api_search_logs_top_get"
  get '/api/search-logs/top' do
    content_type :json

    expected_key = ENV.fetch('CRAWLER_API_KEY', nil)
    if expected_key
      provided = request.env['HTTP_AUTHORIZATION']&.delete_prefix('Bearer ')
      unless provided == expected_key
        status 401
        return { error: 'Unauthorized' }.to_json
      end
    end

    limit = params[:limit].to_i
    limit = 10 if limit <= 0
    limit = [limit, 50].min

    top = SearchLog
          .group(:query)
          .order(Arel.sql('COUNT(*) DESC'))
          .limit(limit)
          .pluck(:query)

    status 200
    { data: top }.to_json
  end

  # POST /api/pages - Batch upsert scraped pages (used by crawler)
  # OpenAPI: operationId "batch_upsert_pages_api_pages_post"
  post '/api/pages' do
    content_type :json

    expected_key = ENV.fetch('CRAWLER_API_KEY', nil)
    if expected_key.nil? && ENV.fetch('RACK_ENV', 'development') == 'production'
      status 500
      return { error: 'CRAWLER_API_KEY is not configured' }.to_json
    end

    if expected_key
      provided = request.env['HTTP_AUTHORIZATION']&.delete_prefix('Bearer ')
      unless provided == expected_key
        status 401
        return { error: 'Unauthorized' }.to_json
      end
    end

    pages = params['pages']

    unless pages.is_a?(Array) && !pages.empty?
      status 422
      return { error: "'pages' must be a non-empty array" }.to_json
    end

    records = pages.filter_map do |p|
      next unless p.is_a?(Hash) &&
                  !p['title'].to_s.strip.empty? &&
                  !p['url'].to_s.strip.empty? &&
                  !p['content'].to_s.strip.empty?

      {
        title: p['title'].strip,
        url: p['url'].strip,
        language: p['language'] || 'en',
        content: p['content'].strip,
        last_updated: Time.now
      }
    end

    if records.empty?
      status 422
      return { error: 'No valid pages in payload' }.to_json
    end

    records = records.uniq { |r| r[:title] }

    Page.upsert_all(records, unique_by: :title)

    status 200
    { inserted: records.length }.to_json
  end

  # GET /api/logout - User logout
  # OpenAPI: operationId "logout_api_logout_get"
  get '/api/logout' do
    content_type :json
    session.clear
    status 200
    { statusCode: 200, message: 'You were logged out' }.to_json
  end

  # GET /logout - Compatibility alias for plotserver test runner
  # OBS: Ikke en del af OpenAPI spec - eksisterer kun for at matche plotserverens browser flow
  get '/logout' do
    session.clear
    redirect '/'
  end

  ################################################################################
  # Helper Methods
  ################################################################################

  helpers do
    # Returns the current user from session (nil if nobody is logged in)
    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end

    def logged_in?
      !current_user.nil?
    end

    # Writes one user_activity_logs row per user per ACTIVITY_THROTTLE_SECONDS.
    # No-op if not logged in or if a row was already written within the window.
    # In-memory cache is per-process; with N puma workers we get at most N
    # writes per user per window — acceptable noise for DAU/WAU/MAU accuracy.
    def track_user_activity
      return unless @current_user

      user_id = @current_user.id
      now = Time.now
      ACTIVITY_THROTTLE_MUTEX.synchronize do
        last = ACTIVITY_THROTTLE[user_id]
        return if last && now - last < ACTIVITY_THROTTLE_SECONDS

        ACTIVITY_THROTTLE[user_id] = now
        # Opportunistic eviction: if the cache grows past 10k entries (well
        # above our user count) prune anything older than the throttle window.
        # Worst case: an evicted-too-early user gets one extra write.
        if ACTIVITY_THROTTLE.size > 10_000
          cutoff = now - ACTIVITY_THROTTLE_SECONDS
          ACTIVITY_THROTTLE.delete_if { |_, t| t < cutoff }
        end
      end

      begin
        UserActivityLog.create(user_id: user_id, path: request.path_info)
      rescue StandardError => e
        logger.error("Failed to log user activity: #{e.message}")
      end
    end
  end

  ################################################################################
  # Error Handlers
  ################################################################################

  not_found do
    content_type :json
    status 404
  end

  error do
    content_type :json
    status 500

    err = env['sinatra.error']
    @exception_class = err.class.name
    first_frame = err.backtrace&.first&.sub(%r{^.*/(?=[^/]+:[0-9]+)}, '')

    EXCEPTIONS_TOTAL.increment(
      labels: { path: self.class.normalize_path(request.path_info), error_class: @exception_class }
    )

    begin
      ExceptionLog.create(
        path: request.path_info,
        http_method: request.request_method,
        error_class: @exception_class,
        error_message: err.message&.slice(0, 500),
        first_frame: first_frame
      )
    rescue StandardError => e
      logger.error("Failed to log exception: #{e.message}")
    end
  end

  run! if app_file == $PROGRAM_NAME
end
