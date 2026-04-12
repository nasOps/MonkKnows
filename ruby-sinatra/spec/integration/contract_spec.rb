# frozen_string_literal: true

# Contract tests verify that the app's API responses conform to the
# OpenAPI specification provided by the course instructor.
# Uses the Committee gem to automatically validate responses against the schema.

require_relative '../spec_helper'
require 'committee'

RSpec.describe 'OpenAPI Contract' do
  include Rack::Test::Methods
  include Committee::Test::Methods

  def app
    WhoknowsApp
  end

  # Points Committee to the OpenAPI spec file
  def committee_options
    @committee_options ||= {
      schema: Committee::Drivers.load_from_file(
        File.expand_path('../../openapi.json', __dir__)
      ),
      raise_schema_errors: true
    }
  end

  # HTML endpoints — spec requires 200 text/html
  describe 'GET /' do
    it 'conforms to OpenAPI spec' do
      get '/'
      assert_response_schema_confirm(200)
    end
  end

  describe 'GET /weather' do
    it 'conforms to OpenAPI spec' do
      get '/weather'
      assert_response_schema_confirm(200)
    end
  end

  describe 'GET /register' do
    it 'conforms to OpenAPI spec' do
      get '/register'
      assert_response_schema_confirm(200)
    end
  end

  describe 'GET /login' do
    it 'conforms to OpenAPI spec' do
      get '/login'
      assert_response_schema_confirm(200)
    end
  end

  # JSON endpoints — spec requires specific response schemas
  describe 'GET /api/logout' do
    it 'returns AuthResponse conforming to OpenAPI spec' do
      get '/api/logout'
      assert_response_schema_confirm(200)
    end
  end

  describe 'GET /api/search' do
    it 'returns 422 RequestValidationError when q is missing' do
      get '/api/search'
      assert_response_schema_confirm(422)
    end

    it 'returns SearchResponse conforming to OpenAPI spec' do
      get '/api/search?q=test'
      assert_response_schema_confirm(200)
    end
  end

  describe 'POST /api/login' do
    it 'returns 422 HTTPValidationError with invalid credentials' do
      post '/api/login', username: 'nobody', password: 'wrong'
      assert_response_schema_confirm(422)
    end
  end

  describe 'POST /api/register' do
    it 'returns 422 HTTPValidationError with missing fields' do
      post '/api/register', username: '', email: '', password: '', password2: ''
      assert_response_schema_confirm(422)
    end
  end
end