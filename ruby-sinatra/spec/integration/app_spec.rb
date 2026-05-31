# frozen_string_literal: true

require_relative '../../app'
require 'rack/test'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

RSpec.describe 'Whoknows App' do
  include Rack::Test::Methods

  def app
    WhoknowsApp
  end

  # ── GET /hello ──────────────────────────────────────────────────────────────

  describe 'GET /hello' do
    it 'returns 200 OK' do
      get '/hello'
      expect(last_response.status).to eq(200)
    end
  end

  # ── GET / ───────────────────────────────────────────────────────────────────

  describe 'GET /' do
    it 'returns 200 when no user is in session' do
      get '/'
      expect(last_response.status).to eq(200)
    end
  end

  # ── POST /api/login ─────────────────────────────────────────────────────────

  describe 'POST /api/login' do
    it 'returns 422 with invalid credentials' do
      post '/api/login', username: 'nobody', password: 'wrong'
      expect(last_response.status).to eq(422)
    end
  end

  # ── GET /api/logout ─────────────────────────────────────────────────────────

  describe 'GET /api/logout' do
    it 'clears session and returns 200' do
      get '/api/logout'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['message']).to eq('You were logged out')
    end
  end

  # ── POST /api/register ──────────────────────────────────────────────────────

  describe 'POST /api/register' do
    let(:valid_params) do
      { username: 'testuser', email: 'test@example.com', password: 'secret123', password2: 'secret123' }
    end

    after(:each) { User.delete_all }

    it 'returns 200 and success message with valid input' do
      post '/api/register', valid_params
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['message']).to eq('You were successfully registered')
    end

    it 'returns 200 when password2 is omitted (optional per OpenAPI spec)' do
      post '/api/register', valid_params.except(:password2)
      expect(last_response.status).to eq(200)
    end

    it 'returns 200 when password2 is omitted in JSON payload' do
      payload = valid_params.except(:password2).merge(username: 'jsonuser', email: 'json@example.com')
      post '/api/register', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['message']).to eq('You were successfully registered')
    end

    it 'returns 422 when passwords do not match' do
      post '/api/register', valid_params.merge(password2: 'wrongpass')
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['detail'].first['msg']).to eq('The two passwords do not match')
    end

    it 'returns 422 when username is blank' do
      post '/api/register', valid_params.merge(username: '')
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['detail'].first['msg']).to eq('You have to enter a username')
    end

    it 'returns 422 when email is blank' do
      post '/api/register', valid_params.merge(email: '')
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['detail'].first['msg']).to eq('You have to enter a valid email address')
    end

    it 'returns 422 when email format is invalid' do
      post '/api/register', valid_params.merge(email: 'notanemail')
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['detail'].first['msg']).to eq('You have to enter a valid email address')
    end

    it 'returns 422 for duplicate username' do
      post '/api/register', valid_params
      post '/api/register', valid_params.merge(email: 'other@example.com')
      expect(last_response.status).to eq(422)
      body = JSON.parse(last_response.body)
      expect(body['detail'].first['msg']).to eq('The username is already taken')
    end

    it 'stores password as bcrypt hash, not plaintext' do
      post '/api/register', valid_params
      user = User.find_by(username: 'testuser')
      expect(user.password_digest).to start_with('$2a$')
      expect(user.password_digest).not_to eq('secret123')
    end
  end

  # ── GET /metrics ─────────────────────────────────────────────────────────────

  describe 'GET /metrics' do
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
