# Main application file - Routes + Controllers (combined)

require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require_relative 'config/environment'
require_relative 'models/page'        
# require_relative 'models/user' # Uncomment når User model er oprettet


class WhoknowsApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  # Sinatra configuration
  set :public_folder, File.expand_path('../public', __FILE__)
  set :views, File.expand_path('../views', __FILE__)

  # Session configuration (nødvendig for login/logout)
  # enable :sessions
  # set :session_secret, ENV.fetch('SESSION_SECRET') { 'development_secret_key' }

   # Test - no DB needed - http://localhost:4567/hello
  get "/hello" do
    "Sinatra says Hello World!"
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
    @query = params[:q]
    @language = params[:language] || 'en'

    if @query
      @results = Page.where(language: @language)
                    .where("content LIKE ?", "%#{@query}%")
    else
      @results = []
    end

    erb :index
  end

  # GET /weather - Weather page
  # OpenAPI: operationId "serve_weather_page_weather_get"
  get '/weather' do
  end

  # GET /register - Registration page
  # OpenAPI: operationId "serve_register_page_register_get"
  get '/register' do
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

    if q.nil? || q.empty?
      search_results = []
    else
      search_results = Page.where(language: language)
                           .where("content LIKE ?", "%#{q}%")
                           .as_json
    end

    { data: search_results }.to_json
  end

  # GET /api/weather - Weather API endpoint
  # OpenAPI: operationId "weather_api_weather_get"
  get '/api/weather' do
    content_type :json
  end

  # POST /api/register - User registration
  # OpenAPI: operationId "register_api_register_post"
  post '/api/register' do
    content_type :json
  end

  # POST /api/login - User login
  # OpenAPI: operationId "login_api_login_post"
  post '/api/login' do
    content_type :json
  end

  # GET /api/logout - User logout
  # OpenAPI: operationId "logout_api_logout_get"
  get '/api/logout' do
    content_type :json
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