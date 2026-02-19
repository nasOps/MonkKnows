# Main application file - Routes + Controllers (combined)

require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require_relative 'config/environment'
require_relative 'models/page' 
require_relative 'models/user'       
# require_relative 'models/user' # Uncomment når User model er oprettet


class WhoknowsApp < Sinatra::Base # App is defined as a Ruby-class = modular style
  register Sinatra::ActiveRecordExtension

  # Sinatra configuration
  set :public_folder, File.expand_path('../public', __FILE__)
  set :views, File.expand_path('../views', __FILE__)

  # Session configuration (nødvendig for login/logout)
   enable :sessions
   set :session_secret, ENV.fetch('SESSION_SECRET') { 'development_secret_key' }

   # Test - no DB needed - http://localhost:4567/hello
  get "/hello" do
    "Sinatra says Hello World!"
  end

  get "/health" do
    status 200
    "ok"
  end


  ################################################################################
  # Before/After Request Handlers
  ################################################################################

   before do
    # Tilsvarende Flask's before_request
    # Tjek om bruger er logged in, load user fra session, etc.
  end

  after do
    # Tilsvarende Flask's after_request
    # Cleanup, logging, etc.
  end

  ################################################################################
  # HTML Routes (Page Routes)
  ################################################################################

  # GET / - Root/Search page - http://localhost:4567
  # OpenAPI: operationId "serve_root_page__get"
  get '/' do
    erb :index
  end

  get '/search' do
    @q = params[:q]
    @language = params[:language] || 'en'

    if @q && !@q.strip.empty?
      @results = Page.where(language: @language)
                     .where("content LIKE ?", "%#{@q}%")
    else
      @results = []
    end

    erb :search
  end

  # GET /weather - Weather page
  # OpenAPI: operationId "serve_weather_page_weather_get"
  get '/weather' do
  end

  # GET /register - Registration page
  # OpenAPI: operationId "serve_register_page_register_get"
 # GET /register - viser registrerings-formularen
  get '/register' do
    erb :register, locals: { error: nil }
  end

  # GET /login - Login page
  # OpenAPI: operationId "serve_login_page_login_get"
  get '/login' do
  end

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
    search_results = Page.where(language: language)
                         .where("content LIKE ?", "%#{q}%")
                         .as_json

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
      status 400
      return { statusCode: 400, message: "The two passwords do not match" }.to_json
    end

    user = User.new(
      username: params[:username],
      email:    params[:email],
      password: User.hash_password(password || "")
    )

    if user.save
      # Svarer til Flask's "You were successfully registered..."
      status 200
      { statusCode: 200, message: "You were successfully registered and can login now" }.to_json
    else
      # .errors.full_messages.first giver foerste validation-fejl
      # f.eks. "You have to enter a username"
      status 400
      { statusCode: 400, message: user.errors.full_messages.first }.to_json
    end
  end

  # POST /api/login - User login
  # OpenAPI: operationId "login_api_login_post"
  post '/api/login' do
    content_type :json
  end

  # GET /api/logout - User logout
  # OpenAPI: operationId "logout_api_logout_get"
  # POST /api/login - logger brugeren ind
  # Flask-ækvivalent: app.py linje 127-140
  post '/api/login' do
    content_type :json

    user = User.find_by(username: params[:username])

    if user.nil?
      status 422
      return {
        detail: [{ loc: ["body", "username"], msg: "Invalid username", type: "value_error" }]
      }.to_json
    end

    unless user.verify_password(params[:password])
      status 422
      return {
        detail: [{ loc: ["body", "password"], msg: "Invalid password", type: "value_error" }]
      }.to_json
    end

    # Gem bruger-id i session - svarer til Flask's session['user_id'] = user['id']
    session[:user_id] = user.id

    status 200
    { statusCode: 200, message: "You were logged in" }.to_json
  end

  ################################################################################
  # Helper Methods
  ################################################################################

  helpers do
    def current_user
    end

    def logged_in?
    end

    def hash_password(password)
    end

    def verify_password(stored_hash, password)
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

  run! if app_file == $0
  end
