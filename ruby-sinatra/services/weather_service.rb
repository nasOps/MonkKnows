# frozen_string_literal: true

# Integration layer for weather API

require 'benchmark'
require 'net/http'
require 'json'
require 'prometheus/client'

class WeatherService
  BASE_URL = 'https://api.openweathermap.org/data/2.5/weather'
  CACHE_DURATION = 600 # 10 minutes

  DURATION = Prometheus::Client.registry.histogram(
    :app_weather_api_duration_seconds,
    docstring: 'Latency of OpenWeather API calls (cache hits excluded)',
    labels: []
  )
  ERRORS = Prometheus::Client.registry.counter(
    :app_weather_api_errors_total,
    docstring: 'OpenWeather API error count, labeled by error type',
    labels: [:error_type]
  )

  @mutex = Mutex.new
  @cache = nil
  @cached_at = nil

  def self.fetch(city: 'Copenhagen')
    @mutex.synchronize do
      return @cache if cache_fresh?

      refresh_cache(city)
    end
  end

  def self.cache_fresh?
    @cache && @cached_at && (Time.now - @cached_at < CACHE_DURATION)
  end

  def self.refresh_cache(city)
    api_key = ENV.fetch('OPENWEATHER_API_KEY', nil)
    if api_key.nil?
      ERRORS.increment(labels: { error_type: 'missing_api_key' })
      raise 'Missing OPENWEATHER_API_KEY'
    end

    response = call_api(city, api_key)
    @cache = parse_response(response)
    @cached_at = Time.now
    @cache
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    ERRORS.increment(labels: { error_type: e.class.name.split('::').last.downcase })
    raise
  end

  def self.call_api(city, api_key)
    uri = URI("#{BASE_URL}?q=#{city}&appid=#{api_key}&units=metric")
    response = nil
    duration = Benchmark.realtime { response = Net::HTTP.get_response(uri) }
    DURATION.observe(duration)

    return response if response.is_a?(Net::HTTPSuccess)

    ERRORS.increment(labels: { error_type: "http_#{response.code}" })
    return @cache if @cache

    raise "Weather API error: #{response.code}"
  end

  def self.parse_response(response)
    parsed = JSON.parse(response.body)
    {
      city: parsed['name'],
      temperature: parsed['main']['temp'],
      humidity: parsed['main']['humidity'],
      condition: parsed['weather'][0]['description'],
      wind_speed: parsed['wind']['speed'],
      source: 'openweather'
    }
  end
end
