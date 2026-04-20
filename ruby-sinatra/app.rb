# frozen_string_literal: true

# = Less memory usage by freezing string literals

# Main application file - Routes + Controllers (combined)
require 'sinatra'
# require 'sinatra/activerecord'
require 'json'
require_relative 'config/environment'
require_relative 'models/page'
require_relative 'models/user'
require_relative 'services/weather_service'
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'
require 'prometheus/client'

# TODO: Change class name to MonkKnowsApp
# App is defined as modular Sinatra class
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

  # Update user count gauge every 60 seconds in a background thread
  unless ENV['RACK_ENV'] == 'test'
    Thread.new do
      loop do
        ActiveRecord::Base.connection_pool.with_connection do
          USERS_TOTAL.set(User.count)
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

    # Parse JSON body og merge ind i params
    # Begrænset til POST requests da GET aldrig sender JSON body
    next unless request.post? && request.content_type&.include?('application/json')

    request.body.rewind
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
    log_data = {
      timestamp: Time.now.utc.iso8601,
      method: request.request_method,
      path: request.path_info,
      status: response.status,
      ip: request.ip,
      user: session[:user_id] ? Digest::SHA256.hexdigest(session[:user_id].to_s)[0..7] : nil,
      duration_ms: ((Time.now - request.env['sinatra.route_start_time']) * 1000).round(2)
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
                 Page.search(@q, language: @language)
               else
                 []
               end

    erb :index
  end

  # GET /weather - Weather page
  # OpenAPI: operationId "serve_weather_page_weather_get"
  get '/weather' do
    content_type :html
    status 200
    @weather = WeatherService.fetch # @weather makes it accessible in weather.erb
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
      search_results = Page.search(q, language: language).as_json(except: :tsv)

      status 200
      {
        data: search_results
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
  # POST /api/register - opretter en ny bruger
  # Flask-akvivalent: app.py linje 143-165
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
      # Like Flask's "You were successfully registered..."
      status 200
      { statusCode: 200, message: 'You were successfully registered' }.to_json
    else
      # .errors.full_messages.first gives the first validation-error
      # e.g. "You have to enter a username"
      status 422
      { detail: [{ loc: ['body'], msg: user.errors.full_messages.first, type: 'value_error' }] }.to_json
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

    # Gem bruger-id i session - svarer til Flask's session['user_id'] = user['id']
    session[:user_id] = user.id

    status 200
    { statusCode: 200, message: 'You were logged in' }.to_json
  end

  # /api/reset-password removed — force_password_reset column dropped in PostgreSQL migration

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
  end

  run! if app_file == $PROGRAM_NAME
end
