# frozen_string_literal: true

require 'prometheus/client'

# Rack middleware that increments a gauge at the start of every request
# and decrements it when the response is fully sent. Exposes Puma worker
# saturation so we can see "are we maxed out on concurrent requests?"
# under stress-test load.
module Middleware
  class InFlightCounter
    GAUGE = Prometheus::Client.registry.gauge(
      :app_http_requests_in_flight,
      docstring: 'Number of HTTP requests currently being processed',
      labels: []
    )

    def initialize(app)
      @app = app
    end

    def call(env)
      GAUGE.increment
      @app.call(env)
    ensure
      GAUGE.decrement
    end
  end
end
