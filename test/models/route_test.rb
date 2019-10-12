require "test_helper"

class RouteTest < ActiveSupport::TestCase
  
  def test_distance_by_airport_with_known_route
    airport1 = airports(:airport_dfw)
    airport2 = airports(:airport_ord)
    assert_equal(801, Route.distance_by_airport(airport1, airport2))
  end

  def test_distance_by_airport_with_unknown_route
    airport1 = airports(:airport_sea)
    airport2 = airports(:airport_yvr)
    assert_equal(126, Route.distance_by_airport(airport1, airport2))
  end

  def test_distance_by_airport_with_unknown_route_without_coordinates
    airport1 = airports(:airport_sea)
    airport2 = airports(:airport_yyz)
    assert_nil(Route.distance_by_airport(airport1, airport2))
  end

  def test_distance_by_coordinates
    coord1 = [47.4498889,-122.3117778]
    coord2 = [49.193889,-123.184444]
    assert_equal(126, Route.distance_by_coordinates(coord1, coord2))
  end

end