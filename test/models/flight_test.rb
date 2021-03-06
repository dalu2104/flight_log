require 'test_helper'

class FlightTest < ActiveSupport::TestCase
  
  def setup
    @hidden_trip = Trip.new( name:    "Hidden Trip",
                             hidden:  true,
                             purpose: "business")
    
    @hidden_trip.flights.new(origin_airport_id:      1,
                             destination_airport_id: 2,
                             trip_section:           1,
                             departure_date:         "2016-01-01",
                             departure_utc:          "2016-01-01 09:00",
                             airline_id:             1)
    
    @public_trip = Trip.new( name:    "Public Trip",
                             hidden:  false,
                             purpose: "personal")
    
    @public_trip.flights.new(origin_airport_id:      1,
                             destination_airport_id: 2,
                             trip_section:           1,
                             departure_date:         "2016-04-01",
                             departure_utc:          "2016-04-01 11:00",
                             airline_id:             1)
  end
  
  def test_users_can_see_hidden_flights
    # be logged in
    #assert_equal @public_trip.flights.visitor.length, 1
    #assert_equal @hidden_trip.flights.length, 1
    
    #assert @public_trip.flights.visitor.length == 1
    # Can't apply .visitor scope to @public_trip.flights for some reason. But Trip.first.flights.visitor.length works. Research scope and/or write function that isn't scope.
    # Or really just create test database and check returned records
    assert @hidden_trip.flights.length == 1
    
    ######
    # Instead consider writing integration test to check for number of rows in /flights
    ######
  end
  
  def test_visitors_cannot_see_hidden_flights
    # be not logged in
    # write me
  end

  def test_total_distance_with_known_routes
    flights = Flight.where(id: [flights(:flight_ord_dfw).id,flights(:flight_sea_ord).id])
    assert_equal(2517, flights.total_distance)
  end

  def test_total_distance_with_an_unknown_route_without_coordinates_allowing_unknown_distances
    flights = Flight.where(id: flights(:flight_layover_ratio_unknown_distance_f2).id)
    assert_equal(0, flights.total_distance(true))
  end

  def test_total_distance_with_an_unknown_route_without_coordinates
    flights = Flight.where(id: flights(:flight_layover_ratio_unknown_distance_f2).id)
    assert_nil(flights.total_distance(false))
  end
  
end
