# frozen_string_literal: true

# Integration layer for weather API

require 'net/http' # To make HTTP requests to the weather API
require 'json' # To parse JSON responses from the weather API

class WeatherService
  BASE_URL = 'https://api.openweathermap.org/data/2.5/weather'

  # ---- Caching mechanism to reduce API calls and improve performance ----
  CACHE_DURATION = 600 # 10 minutter

  @@cache = nil # Class variable to store cached weather data
  @@cached_at = nil # Timestamp for when the data was cached

  def self.fetch(city: 'Copenhagen')
    # Return cached data if still valid
    return @@cache if @@cache && @@cached_at && (Time.now - @@cached_at < CACHE_DURATION)

    api_key = ENV.fetch('OPENWEATHER_API_KEY', nil) # Reads the API key from .env file
    raise 'Missing OPENWEATHER_API_KEY' if api_key.nil?

    uri = URI("#{BASE_URL}?q=#{city}&appid=#{api_key}&units=metric") # Building the API URL with query parameters
    response = Net::HTTP.get_response(uri) # Making the HTTP GET request to the weather API

    unless response.is_a?(Net::HTTPSuccess) # Checking if the response is successful (status code 200)
      # 🔥 Fallback to cache if available
      return @@cache if @@cache

      raise "Weather API error: #{response.code}"
    end

    parsed = JSON.parse(response.body) # Parsing the JSON response from the API

    # Extracting relevant weather data and returning it in a structured format
    weather_data = {
      city: parsed['name'],
      temperature: parsed['main']['temp'],
      humidity: parsed['main']['humidity'],
      condition: parsed['weather'][0]['description'],
      wind_speed: parsed['wind']['speed'],
      source: 'openweather'
    }

    # Save to cache
    @@cache = weather_data
    @@cached_at = Time.now

    weather_data
  end
end
