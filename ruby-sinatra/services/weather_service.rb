# Integration layer for weather API

require 'net/http'
require 'json'

class WeatherService
  BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

  def self.fetch(city: "Copenhagen")
    api_key = ENV["OPENWEATHER_API_KEY"] # Reads the API key from .env file
    raise "Missing OPENWEATHER_API_KEY" if api_key.nil?

    uri = URI("#{BASE_URL}?q=#{city}&appid=#{api_key}&units=metric") # Building the API URL with query parameters

    response = Net::HTTP.get_response(uri) # Making the HTTP GET request to the weather API

    unless response.is_a?(Net::HTTPSuccess) # Checking if the response is successful (status code 200)
      raise "Weather API error: #{response.code}"
    end

    parsed = JSON.parse(response.body) # Parsing the JSON response from the API

    { # Extracting relevant weather data and returning it in a structured format
      city: parsed["name"],
      temperature: parsed["main"]["temp"],
      humidity: parsed["main"]["humidity"],
      condition: parsed["weather"][0]["description"],
      wind_speed: parsed["wind"]["speed"],
      source: "openweather"
    }
  end
end