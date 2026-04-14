# frozen_string_literal: true

# When single testing we need the environment to start ActiveRecord
# (to work with DB using Ruby syntax and not SQL language)
require_relative '../../config/environment'
require_relative '../../models/user'

RSpec.describe User do
  # Tests the class method that hashes a plain-text password using BCrypt
  describe '.hash_password' do
    # BCrypt hashes always start with "$2a$" — verifies correct algorithm is used
    it 'returns a BCrypt hash string' do
      result = User.hash_password('secret123')
      expect(result).to be_a(String)
      expect(result).to start_with('$2a$') # BCrypt-format
    end

    # BCrypt adds a random salt on every call, so identical inputs produce different hashes
    it 'two calls produce different hashes (salt)' do
      hash1 = User.hash_password('same_password')
      hash2 = User.hash_password('same_password')
      expect(hash1).not_to eq(hash2) # BCrypt salter hver gang
    end
  end

  # Tests the instance method that verifies a login attempt against stored credentials
  describe '#verify_password?' do
    # Modern path: password is stored as a BCrypt digest
    context 'with bcrypt password_digest' do
      it 'returns true for correct password' do
        # User.new(...) creates ruby object in memory > not saved to DB, so we can test verify_password? without
        # DB interaction
        user = User.new(password_digest: BCrypt::Password.create('correct'))
        expect(user.verify_password?('correct')).to be true
      end

      it 'returns false for wrong password' do
        user = User.new(password_digest: BCrypt::Password.create('correct'))
        expect(user.verify_password?('wrong')).to be false
      end
    end

    # Legacy path: password was stored as an MD5 hex string (old Flask app)
    context 'with legacy MD5 password' do
      it 'returns true and migrates to bcrypt' do
        user = User.new(password: Digest::MD5.hexdigest('oldpass'), password_digest: nil)
        # Stub migrate_to_bcrypt! to avoid hitting the database in a unit test
        allow(user).to receive(:migrate_to_bcrypt!)
        expect(user.verify_password?('oldpass')).to be true
        expect(user).to have_received(:migrate_to_bcrypt!)
      end
    end
  end
end
