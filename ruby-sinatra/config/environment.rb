# frozen_string_literal: true

# Load gems & setup environment

require 'bundler'
Bundler.require

require 'sinatra/activerecord'

# Set database configuration
set :database_file, File.expand_path('database.yml', __dir__)
