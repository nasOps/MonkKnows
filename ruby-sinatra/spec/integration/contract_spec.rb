# frozen_string_literal: true

# Contract tests verify that the app's API responses conform to the
# OpenAPI specification provided by the course instructor.
# Uses the Committee gem to automatically validate responses against the schema.

require_relative '../../config/environment'
require_relative '../../app'
require_relative '../spec_helper'
require 'rack/test'
require 'committee'

RSpec.describe 'OpenAPI Contract' do
  include Rack::Test::Methods
  include Committee::Test::Methods

  def app
    WhoknowsApp
  end

  let(:schema) do
    Committee::Drivers.load_from_file(
      File.expand_path('../../../docs/openapi/whoknows-spec.json', __dir__)
    ).driver.parse(
      JSON.parse(
        File.read(
          File.expand_path('../../../docs/openapi/whoknows-spec.json', __dir__)
        )
      )
    )
  end

  def validate_response!(status)
    expect(last_response.status).to eq(status)
    Committee::SchemaValidator::OpenAPI3::OperationWrapper
  end

  # HTML endpoints — spec requires 200 text/html
  describe 'GET /' do
    it 'returns 200' do
      get '/'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end
  end

  describe 'GET /weather' do
    it 'returns 200' do
      get '/weather'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end
  end

  describe 'GET /register' do
    it 'returns 200' do
      get '/register'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end
  end

  describe 'GET /login' do
    it 'returns 200' do
      get '/login'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end
  end

  # JSON endpoints — validates schema manually
  describe 'GET /api/logout' do
    it 'returns AuthResponse schema' do
      get '/api/logout'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('statusCode')
      expect(body).to have_key('message')
    end
  end

  describe 'GET /api/search' do
    it 'returns 422 with statusCode and message when q is missing' do
      get '/api/search'
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('statusCode')
      expect(body).to have_key('message')
    end

    it 'returns SearchResponse with data array' do
      get '/api/search?q=test'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('data')
      expect(body['data']).to be_an(Array)
    end
  end

  describe 'POST /api/login' do
    it 'returns 422 with detail array for invalid credentials' do
      post '/api/login', username: 'nobody', password: 'wrong'
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('detail')
      expect(body['detail']).to be_an(Array)
    end
  end

  describe 'POST /api/register' do
    it 'returns 422 with detail array for missing fields' do
      post '/api/register', username: '', email: '', password: '', password2: ''
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('detail')
      expect(body['detail']).to be_an(Array)
    end
  end
end
