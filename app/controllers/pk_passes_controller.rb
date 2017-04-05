class PkPassesController < ApplicationController
  before_action :logged_in_user
  
  def index
    @title = "Import Boarding Passes"
    
    # Determine an appropriate trip to use:
    begin
      @trip = Trip.find(params[:trip_id])
    rescue ActiveRecord::RecordNotFound
      if Trip.where(hidden: true).any?
        @trip = Trip.where(hidden: true).order(:created_at).last
      elsif Trip.any?
        @trip = Trip.order(:created_at).last
      else
        flash[:record_not_found] = "No trips have been created yet, so we can’t import a boarding pass. Please create a trip."
        redirect_to new_trip_path
      end
    end
    
    @trips = Trip.with_departure_dates(logged_in?).reverse.map{|trip| ["#{trip.name} / #{format_date(trip.departure_date)}", trip.id]}
    @passes = PKPass.pass_summary_list
    @flight_passes = PKPass.flights_with_updated_passes
    @flights = Flight.flights_table.where(id: @flight_passes.keys)
    @flights = @flights.visitor if !logged_in? # Filter out hidden trips for visitors
    
    check_email_for_boarding_passes      
    
  end
  
  def change_trip
    redirect_to import_boarding_passes_path(trip_id: params[:trip_id])
  end
  
  def destroy
    PKPass.find(params[:id]).destroy
    flash[:success] = "Pass destroyed."
    redirect_to trip_path(Trip.find(params[:trip_id]))
  end
  
  private
  
    
  
end