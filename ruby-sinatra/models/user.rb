# frozen_string_literal: true

require 'digest'

# User-model - mapper til 'users'-tabellen via ActiveRecord.
# ActiveRecord finder automatisk tabellen ud fra klassenavnet (User => users).
class User < ActiveRecord::Base
  # Validations - svarer til if/elsif-tjek i Flask's /api/register route
  validates :username, presence: { message: 'You have to enter a username' },
                       uniqueness: { message: 'The username is already taken' }

  validates :email, presence: { message: 'You have to enter a valid email address' },
                    format: { with: /@/, message: 'You have to enter a valid email address' }

  validates :password, presence: { message: 'You have to enter a password' }

  # MD5-hashing - samme som Flask's hashlib.md5()
  # Klassemetode (self.) - kaldes med User.hash_password("test")
  def self.hash_password(password)
    Digest::MD5.hexdigest(password)
  end

  # Instansmetode - kaldes paa et user-objekt: user.verify_password("test")
  def verify_password?(plain_password)
    password == User.hash_password(plain_password)
  end
end
