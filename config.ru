require 'rubygems'
require 'bundler'
require 'securerandom'

Bundler.require

# Generate a secure session secret if not set
ENV['SESSION_SECRET'] ||= SecureRandom.hex(32)

# Load environment variables
require 'dotenv'
Dotenv.load('.env.local', '.env') if ENV['RACK_ENV'] != 'production'

require './admin/app'

# Enable logging
use Rack::Logger

# Map the admin panel to /admin path
map '/admin' do
  # Set up session middleware
  use Rack::Session::Cookie, 
    key: 'admin.session',
    secret: ENV['SESSION_SECRET'],
    same_site: :lax,
    path: '/',
    expire_after: 86400,
    secure: false,
    httponly: true,
    sidbits: 128

  # Add CSRF protection
  use Rack::Protection, 
    :session => true,
    :except => [:remote_token, :session_hijacking, :authenticity_token]

  run AdminPanel
end 