# frozen_string_literal: true

# Integration layer for weather API

require 'net/http'
require 'json'

class WeatherService
  BASE_URL = 'https://api.openweathermap.org/data/2.5/weather'
  CACHE_DURATION = 600 # 10 minutes

  @mutex = Mutex.new
  @cache = nil
  @cached_at = nil

  def self.fetch(city: 'Copenhagen')
    @mutex.synchronize do
      return @cache if @cache && @cached_at && (Time.now - @cached_at < CACHE_DURATION)

      api_key = ENV.fetch('OPENWEATHER_API_KEY', nil)
      raise 'Missing OPENWEATHER_API_KEY' if api_key.nil?

      uri = URI("#{BASE_URL}?q=#{city}&appid=#{api_key}&units=metric")
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        return @cache if @cache

        raise "Weather API error: #{response.code}"
      end

      parsed = JSON.parse(response.body)

      @cache = {
        city: parsed['name'],
        temperature: parsed['main']['temp'],
        humidity: parsed['main']['humidity'],
        condition: parsed['weather'][0]['description'],
        wind_speed: parsed['wind']['speed'],
        source: 'openweather'
      }
      @cached_at = Time.now

      @cache
    end
  end
end
