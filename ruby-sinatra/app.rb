# Main application file - Routes + Controllers (combined)

require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require_relative 'config/environment'
require_relative 'models/page'


class WhoknowsApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  # set is Sinatra Configuration-method
  set :public_folder, File.expand_path('../public', __FILE__)
  set :views, File.expand_path('../views', __FILE__)

  # Test - no DB needed
  get "/hello" do
    "Sinatra says Hello World!"
  end

  # === HTML routes - for user interface (HTML-responses) ===

  get "/" do
    erb :index # This will render the views/index.erb file as the homepage
  end

  get '/search' do
    @query = params[:q] # Gets query parameter from URL, e.g. /search?q=example
    @language = params[:language] || 'en' # Default to English if no language is specified

    if @query # Variable used in HTML-template
      @results = Page.where(language: @language)
                     .where("content LIKE ?", "%#{@query}%")
    else
      @results = []
    end

    erb :'search/results'
  end

  # === API routes (JSON responses) ===

  # API endpoint for searching pages
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

    { search_results: search_results }.to_json
  end

  run! if app_file == $0
end