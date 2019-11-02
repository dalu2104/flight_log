require "test_helper"

class RouteFlowsTest < ActionDispatch::IntegrationTest

  def setup
    @visible_route = [airports(:airport_visible_1), airports(:airport_visible_2)]
    @hidden_route = [airports(:airport_hidden_1), airports(:airport_hidden_2)]
  end
  
  ##############################################################################
  # Tests for Spec > Pages (Views) > Edit Route                                #
  ##############################################################################

  test "can see edit route when logged in" do
    route = routes(:route_dfw_ord)
    log_in_as(users(:user_one))
    get(edit_route_path(route.airport1, route.airport2))
    assert_response(:success)

    assert_select("h1", ["Edit", route.airport1.iata_code, Route::ARROW_TWO_WAY_PLAINTEXT, route.airport2.iata_code].join(" "))
    assert_select("input#route_distance_mi[value=?]", route.distance_mi.to_s)
    assert_select("input[type=submit][value=?]", "Submit")
  end

  test "cannot see edit route when not logged in" do
    route = routes(:route_dfw_ord)
    get(edit_route_path(route.airport1, route.airport2))
    assert_redirected_to(root_path)
  end

  ##############################################################################
  # Tests for Spec > Pages (Views) > Index Routes                              #
  ##############################################################################

  test "can see index routes when logged in" do
    routes = Route.flight_table_data(logged_in_flights)
    
    log_in_as(users(:user_one))
    get(routes_path)
    assert_response(:success)

    assert_select("h1", "Routes")

    assert_select("table#route-count-table") do
      check_flight_row(routes, @visible_route, "This view should show routes with visible flights")
      check_flight_row(routes, @hidden_route, "This view should show routes with hidden flights when logged in")
      assert_select("td#route-count-total", {text: /^#{routes.size} routes?/}, "Ranked tables shall have a total row with a correct total")
    end
  end

  test "can see index routes when not logged in" do
    routes = Route.flight_table_data(visitor_flights)

    get(routes_path)
    assert_response(:success)

    assert_select("h1", "Routes")

    assert_select("table#route-count-table") do
      check_flight_row(routes, @visible_route, "This view should show routes with visible flights")
      assert_select("tr#route-count-row-#{@hidden_route.pluck(:slug).sort.join("-to-")}", {count: 0}, "This view should not show routes with hidden flights when not logged in")
      assert_select("td#route-count-total", {text: /^#{routes.size} routes?/}, "Ranked tables shall have a total row with a correct total")
    end
  end

  private

  # Runs tests on a row in a route count table
  def check_flight_row(flight_table_data, route_to_check, error_message)
    route_data = flight_table_data.find{|r| r[:route].sort == route_to_check.sort}
    sorted_slugs = route_to_check.pluck(:slug).sort
    assert_select("tr#route-count-row-#{sorted_slugs.join("-to-")}", {}, error_message) do
      assert_select("a[href=?]", show_route_path(*sorted_slugs))
      assert_select("text.graph-distance", route_data[:distance_mi].to_s, "Graph bar should have the correct distance")
      assert_select("text.graph-value", route_data[:flight_count].to_s, "Graph bar should have the correct flight count")
    end
  end
  
end
