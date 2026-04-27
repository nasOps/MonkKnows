# frozen_string_literal: true

# .ru = RackUp file
# This file is used to start the Sinatra application using the Rack web server interface.

require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'
require './middleware/in_flight_counter'
require './app'

# Prometheus middleware — must be mounted before the app
# Collector: auto-tracks http_server_requests_total and http_server_request_duration_seconds
# Exporter: exposes /metrics endpoint for Prometheus to scrape
# InFlightCounter: gauge for currently-processing requests (Puma saturation)
use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter
use Middleware::InFlightCounter

run WhoknowsApp
