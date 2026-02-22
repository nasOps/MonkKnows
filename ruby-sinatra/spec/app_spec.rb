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
end
