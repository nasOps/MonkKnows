# frozen_string_literal: true

require 'bcrypt'
require 'digest'

# User-model - mapper til 'users'-tabellen via ActiveRecord.
# ActiveRecord finder automatisk tabellen ud fra klassenavnet (User => users).
class User < ActiveRecord::Base
  # Validations - svarer til if/elsif-tjek i Flask's /api/register route
  validates :username, presence: { message: 'You have to enter a username' },
                       uniqueness: { message: 'The username is already taken' }

  validates :email, presence: { message: 'You have to enter a valid email address' },
                    format: { with: /\A[^@\s]+@[^@\s]+\z/, message: 'You have to enter a valid email address' }

  validates :password, presence: { message: 'You have to enter a password' }, if: :needs_password?

  # Hash password med bcrypt for nye brugere
  def self.hash_password(password)
    BCrypt::Password.create(password)
  end

  # Gradvis migration: verificer mod bcrypt eller MD5, re-hash hvis MD5
  def verify_password?(input)
    if password_digest
      BCrypt::Password.new(password_digest) == input
    elsif password == Digest::MD5.hexdigest(input)
      migrate_to_bcrypt!(input)
      true
    else
      false
    end
  end

  private

  # Re-hash MD5 password til bcrypt ved succesfuldt login
  def migrate_to_bcrypt!(plain_password)
    update_columns(password_digest: BCrypt::Password.create(plain_password), password: nil)
  end

  # Kun kræv password ved oprettelse (ikke ved bcrypt migration)
  def needs_password?
    password_digest.nil? && new_record?
  end
end
