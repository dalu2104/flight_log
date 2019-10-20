ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require "rails/test_help"
require "minitest/reporters"
Minitest::Reporters.use!

class ActiveSupport::TestCase
  
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  set_fixture_class(pk_passes: PKPass)
  
  # Logs in a test user
  def log_in_as(user)
    cookies[:remember_token] = user.remember_token
  end

  # Returns all flights
  def logged_in_flights
    users(:user_one).flights(users(:user_one))
  end
  
  # Returns non-hidden flights
  def visitor_flights
    users(:user_one).flights(nil)
  end

  end