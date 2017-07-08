class RoutesController < ApplicationController
  before_action :logged_in_user, :only => [:new, :create, :edit, :update, :destroy]
  add_breadcrumb 'Home', 'root_path'
  
  def index
    add_breadcrumb 'Routes', 'routes_path'
    @title = "Routes"
    @meta_description = "A list of the routes Paul Bogard has flown on, and how often heʼs flown on each."
        
    flights = flyer.flights(current_user)
    @route_table = Route.flight_count(flights)     
    
    if @route_table.count > 0
      
      # Find maxima for graph scaling:
      @flights_maximum = @route_table.max_by{|i| i[:flight_count].to_i}[:flight_count]
      @distance_maximum = @route_table.max_by{|i| i[:distance_mi].to_i}[:distance_mi]
  
      # Sort route table:
      sort_params = sort_parse(params[:sort], %w(flights distance), :desc)
      @sort_cat   = sort_params[:category]
      @sort_dir   = sort_params[:direction]
      sort_mult   = (@sort_dir == :asc ? 1 : -1)
      if @sort_cat == :flights
        @route_table = @route_table.sort_by {|value| [sort_mult*(value[:flight_count] || 0), -(value[:distance_mi] || -1)]}
      elsif @sort_cat == :distance
        @route_table = @route_table.sort_by {|value| [sort_mult*(value[:distance_mi] || -1), -(value[:flight_count] || 0)]}
      end
    end
    
  end
  
  def show
    @airports = Array.new
    if params[:id].to_i > 0
      current_route = Route.find(params[:id])
      @airports.push(Airport.find(current_route.airport1_id).iata_code)
      @airports.push(Airport.find(current_route.airport2_id).iata_code)
      @route_string = @airports.join('-')
    else
      @airports = params[:id].split('-')
      @route_string = params[:id]
    end
    
    airport_lookup = Array.new()
    @airports_id = Array.new()
    @airports_city = Array.new()
    raise ActiveRecord::RecordNotFound if Airport.where(:iata_code => @airports[0]).length == 0 || Airport.where(:iata_code => @airports[1]).length == 0
    @airports.each_with_index do |airport, index|
      airport_lookup[index] = Airport.where(:iata_code => airport).first
      @airports_id[index] = airport_lookup[index].id
      @airports_city[index] = airport_lookup[index].city
    end
    
    add_breadcrumb 'Routes', 'routes_path'
    add_breadcrumb "#{@airports[0]} – #{@airports[1]}", route_path(@route_string)
    add_admin_action view_context.link_to("Edit Route", edit_route_path(@airports[0],@airports[1]))
    @title = "#{@airports[0]} – #{@airports[1]}"
    @meta_description = "Maps and lists of Paul Bogardʼs flights between #{@airports[0]} and #{@airports[1]}."
    @logo_used = true
    
    flyer_flights = flyer.flights(current_user).includes(:airline, :origin_airport, :destination_airport, :trip)
    @flights = flyer_flights.where("(origin_airport_id = :city1 AND destination_airport_id = :city2) OR (origin_airport_id = :city2 AND destination_airport_id = :city1)", {:city1 => @airports_id[0], :city2 => @airports_id[1]})
    
    raise ActiveRecord::RecordNotFound if @flights.length == 0
    
    @pair_distance = Route.distance_by_iata(@airports[0],@airports[1])
    
    # Get trips sharing this city pair:
    trip_array = Array.new
    @sections = Array.new
    section_where_array = Array.new
    @flights.each do |flight|
      trip_array.push(flight.trip_id)
      @sections.push( {:trip_id => flight.trip_id, :trip_name => flight.trip.name, :trip_section => flight.trip_section, :departure => flight.departure_date, :trip_hidden => flight.trip.hidden} )
      section_where_array.push("(trip_id = #{flight.trip_id.to_i} AND trip_section = #{flight.trip_section.to_i})")
    end
    trip_array.uniq!
    @sections.uniq!
    section_where_array.uniq!
    
    # Create list of trips sorted by first flight:
    
    if logged_in?
      @trips = Flight.find_by_sql(["SELECT flights.trip_id, trips.id, trips.name, trips.hidden, MIN(flights.departure_date) AS departure_date FROM flights JOIN trips ON flights.trip_id = trips.id WHERE flights.trip_id IN (?) GROUP BY flights.trip_id, trips.id, trips.name, trips.hidden ORDER BY departure_date", trip_array])
    else
      @trips = Flight.find_by_sql(["SELECT flights.trip_id, trips.id, trips.name, trips.hidden, MIN(flights.departure_date) AS departure_date FROM flights JOIN trips ON flights.trip_id = trips.id WHERE flights.trip_id IN (?) AND trips.hidden = false GROUP BY flights.trip_id, trips.id, trips.name, trips.hidden ORDER BY departure_date", trip_array])
    end
    
    # Create comparitive lists of airlines, aircraft, and classes:
    @airlines = Airline.flight_count(@flights, type: :airline)
    @operators = Airline.flight_count(@flights, type: :operator)
    @aircraft_families = AircraftFamily.flight_count(@flights)
    @classes = TravelClass.flight_count(@flights)
    
    # Create flight arrays for maps of trips and sections:
    @city_pair_trip_flights    = flyer_flights.where(:trip_id => trip_array)
    @city_pair_section_flights = flyer_flights.where(section_where_array.join(' OR '))
    
    # Create maps:
    @route_map    = SingleFlightMap.new(@flights.first)
    @sections_map = HighlightedRoutesMap.new(@city_pair_section_flights, @flights)
    @trips_map    = HighlightedRoutesMap.new(@city_pair_trip_flights, @flights)
    
    rescue ActiveRecord::RecordNotFound
      flash[:warning] = "We couldnʼt find any flights with the route #{params[:id]}. Instead, weʼll give you a list of routes."
      redirect_to routes_path
    
    
  end
  
  def edit
    add_breadcrumb 'Routes', 'routes_path'
    add_breadcrumb "#{params[:airport1]} - #{params[:airport2]}", route_path("#{params[:airport1]}-#{params[:airport2]}")
    add_breadcrumb 'Edit', '#'
    @title = "Edit #{params[:airport1]} - #{params[:airport2]}"
    
    # Get airport ids:
    @airport_ids = Array.new
    @airport_ids.push(Airport.where(:iata_code => params[:airport1]).first.try(:id))
    @airport_ids.push(Airport.where(:iata_code => params[:airport2]).first.try(:id))
    raise ArgumentError if @airport_ids.include?(nil)
    @airport_ids.sort! # Ensure IDs are in order
    
    # Check to see if route already exists in database. If so, edit it, if not, new route.
    current_route = Route.where("(airport1_id = ? AND airport2_id = ?) OR (airport1_id = ? AND airport2_id = ?)", @airport_ids[0], @airport_ids[1], @airport_ids[1], @airport_ids[0])
    if current_route.present?
      # Route exists, edit it.
      @route = current_route.first
      
    else
      # Route does not exist, create a new one.
      @route = Route.new
    end
    
    rescue ArgumentError
      flash[:warning] = "Canʼt look up route - at least one of these airports does not exist in the database."
      redirect_to routes_path
    
  end
  
  def create
    @route = Route.new(route_params)
    if @route.save
      flash[:success] = "Successfully added distance to route!"
      redirect_to route_path("#{@route.airport1.iata_code}-#{@route.airport2.iata_code}")
    else
      render 'new'
    end
  end
  
  def update
    @route = Route.find(params[:id])
    if @route.update_attributes(route_params)
      flash[:success] = "Successfully updated route distance."
      redirect_to route_path("#{@route.airport1.iata_code}-#{@route.airport2.iata_code}")
    else
      render 'edit'
    end
  end
  
  private
  
    def route_params
      params.require(:route).permit(:airport1_id, :airport2_id, :distance_mi)
    end
end
  
