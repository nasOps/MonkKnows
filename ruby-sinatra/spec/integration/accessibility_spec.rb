# frozen_string_literal: true

require_relative '../../app'
require 'rack/test'

RSpec.describe 'Accessibility' do
  include Rack::Test::Methods

  def app
    WhoknowsApp
  end

  describe 'Global layout' do
    before { get '/' }

    it 'has lang attribute on html element' do
      expect(last_response.body).to include('lang="en"')
    end

    it 'has aria-live on toast notification' do
      expect(last_response.body).to include('aria-live="polite"')
    end

    it 'has a main landmark' do
      expect(last_response.body).to include('role="main"')
    end
  end

  describe 'GET / (search page)' do
    before { get '/' }

    it 'has accessible name on search input' do
      expect(last_response.body).to match(/aria-label="[^"]+"|<label[^>]+for="search-input"/)
    end

    it 'has role=search on the search form' do
      expect(last_response.body).to include('role="search"')
    end

    it 'has aria-expanded on custom dropdown toggle' do
      expect(last_response.body).to include('aria-expanded=')
    end
  end

  describe 'GET /login' do
    before { get '/login' }

    it 'has label for username input' do
      expect(last_response.body).to include('for="username"')
      expect(last_response.body).to include('id="username"')
    end

    it 'has label for password input' do
      expect(last_response.body).to include('for="password"')
      expect(last_response.body).to include('id="password"')
    end
  end

  describe 'GET /register' do
    before { get '/register' }

    it 'has label for username input' do
      expect(last_response.body).to include('for="reg-username"')
    end

    it 'has label for email input' do
      expect(last_response.body).to include('for="reg-email"')
    end

    it 'has label for password inputs' do
      expect(last_response.body).to include('for="reg-password"')
      expect(last_response.body).to include('for="reg-password2"')
    end

    it 'email field uses type=email' do
      expect(last_response.body).to include('type="email"')
    end
  end

  describe 'GET /weather' do
    before { get '/weather' }

    it 'has aria-hidden on decorative SVGs' do
      expect(last_response.body).to include('aria-hidden="true"')
    end
  end
end
