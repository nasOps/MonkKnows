# frozen_string_literal: true

require_relative '../../app'
require 'rack/test'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

## This module provides methods like `get`, `post`, etc.
# to simulate HTTP requests in tests.
RSpec.describe 'Whoknows App' do
  include Rack::Test::Methods

  def app
    WhoknowsApp # Tells RSpec which app to test
  end

  describe 'GET /hello' do
    it 'returns 200 OK' do
      get '/hello'
      expect(last_response.status).to eq(200)
    end
  end

  describe 'Session management' do
    # Test 1: before-filter sætter @current_user til nil når ingen er logget ind
    describe 'before filter' do
      it 'loads without error when no user is in session' do
        get '/'
        expect(last_response.status).to eq(200)
      end
    end

    # Test 2: login returnerer 422 og sætter ikke session ved forkerte credentials
    describe 'POST /api/login' do
      it 'returns 422 with invalid credentials' do
        post '/api/login', username: 'nobody', password: 'wrong'
        expect(last_response.status).to eq(422)
      end
    end

    # Test 3: logout rydder session og returnerer 200
    describe 'GET /api/logout' do
      it 'clears session and returns 200' do
        get '/api/logout'
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('You were logged out')
      end
    end
  end

  describe 'GET /metrics' do
    # Build the full Rack stack with Prometheus middleware (as in config.ru)
    let(:full_app) do
      Rack::Builder.new do
        use Prometheus::Middleware::Collector
        use Prometheus::Middleware::Exporter
        run WhoknowsApp
      end
    end

    it 'returns 200 with Prometheus metrics' do
      env = Rack::MockRequest.env_for('/metrics')
      status, _headers, body = full_app.call(env)
      response_body = body.map(&:to_s).join
      expect(status).to eq(200)
      expect(response_body).to include('http_server_requests_total')
      expect(response_body).to include('http_server_request_duration_seconds')
    end
  end
end
