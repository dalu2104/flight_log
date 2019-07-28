# Controls administrative pages. Users must be logged in to view any of these pages.

class AdminController < ApplicationController
  before_action :logged_in_user
  
  # Shows the administrative main menu.
  #
  # This action can only be performed by a verified user.
  #
  # @return [nil]
  def admin
    add_breadcrumb "Admin", admin_path
  end
  
  # Shows a table of the total count of business, mixed, and personal {Flight Flights}
  # for each calendar year.
  #
  # This action can only be performed by a verified user.
  #
  # @return [nil]
  def annual_flight_summary
    add_breadcrumb "Admin", admin_path
    add_breadcrumb "Annual Flight Summary", annual_flight_summary_path
    @flight_summary = Flight.by_year
  end
  
  # Shows the boarding pass data of all {Flight Flights} with invalid boarding pass
  # data.
  #
  # This action can only be performed by a verified user.
  #
  # @return [nil]
  def boarding_pass_validator
    add_breadcrumb "Admin", admin_path
    add_breadcrumb "Boarding Pass Validator", boarding_pass_validator_path
    @pass_flights = Flight.select(:id, :boarding_pass_data).where("boarding_pass_data IS NOT NULL").order(:departure_utc)
  end
  
end
