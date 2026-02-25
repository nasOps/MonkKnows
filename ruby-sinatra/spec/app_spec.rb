# frozen_string_literal: true

require_relative '../app'
require 'rack/test'

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
end
