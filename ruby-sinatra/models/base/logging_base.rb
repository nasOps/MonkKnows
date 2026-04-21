# frozen_string_literal: true

class LoggingBase < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :logging
end
