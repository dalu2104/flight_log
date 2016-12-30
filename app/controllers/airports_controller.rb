class AirportsController < ApplicationController
  before_action :logged_in_user, :only => [:new, :create, :edit, :update, :destroy]
  add_breadcrumb 'Home', 'root_path'
  
  def index
    add_breadcrumb 'Airports', 'airports_path'
    @title = "Airports"
    @meta_description = "Maps and lists of airports Paul Bogard has visited, and how often heʼs visited them."
    @flights = Flight.flights_table
    @flights = @flights.visitor if !logged_in? # Filter out hidden trips for visitors
    
    if @flights.any?
        
      # Create airport table array:
      @airport_table = Airport.airport_table(@flights)
      
      # Create airports with no flights table array:
      if logged_in?
        airport_ids = Airport.region_iata_codes(@flights, :world).keys
        @airports_with_no_flights = Airport.where('id not in (?)',airport_ids)
      end
    
      # Find maxima for graph scaling:
      @visits_maximum = @airport_table.max_by{|i| i[:frequency]}[:frequency]
    
      # Sort route table:
      
      sort_params = sort_parse(params[:sort], %w(visits country city code), :desc)
      @sort_cat   = sort_params[:category]
      @sort_dir   = sort_params[:direction]
      sort_mult   = (@sort_dir == :asc ? 1 : -1)
      
      case @sort_cat
      when :country
        if @sort_dir == :asc
          @airport_table = @airport_table.sort_by {|airport| [airport[:country], airport[:city]]}
        else
          @airport_table = @airport_table.sort {|a, b| [b[:country], a[:city]] <=> [a[:country], b[:city]] }
        end
      when :city
        @airport_table = @airport_table.sort_by {|airport| airport[:city]}
        @airport_table.reverse! if @sort_dir == :desc
      when :code
        @airport_table = @airport_table.sort_by {|airport| airport[:iata_code]}
        @airport_table.reverse! if @sort_dir == :desc
      when :visits
        @airport_table = @airport_table.sort_by { |airport| [sort_mult*airport[:frequency], airport[:city]] }
      end
      
      # Create maps:
      @region = current_region(default: :world)
      @airports_map  = AirportsMap.new(@airport_table, region: @region)
      @frequency_map = AirportFrequencyMap.new(@flights, region: @region)
      
    end
    
  end
  
  
  def show
    @logo_used = true
    if params[:id].to_i > 0
      @airport = Airport.find(params[:id])
    else
      @airport = Airport.where(:iata_code => params[:id]).first
      raise ActiveRecord::RecordNotFound if (@airport.nil?) #all_flights will fail if code does not exist, so check here.
    end
    
    @flights = Flight.flights_table.where("origin_airport_id = ? OR destination_airport_id = ?", @airport.id, @airport.id)
    @flights = @flights.visitor if !logged_in? # Filter out hidden trips for visitors
    
    raise ActiveRecord::RecordNotFound if (@flights.length == 0 && !logged_in?)
    trip_array = Array.new
    @sections = Array.new
    section_where_array = Array.new
    pair_totals = Hash.new(0)
    pair_cities = Hash.new
    pair_countries = Hash.new
    pair_distances = Hash.new
    @direct_flight_airports = Array.new
    prev_trip_id = nil
    prev_section_id = nil
    
    @total_distance = total_distance(@flights)
    
    # Calculate distances to direct flight airports:
    direct_flight_airports = @flights.pluck(:origin_airport_id).concat(@flights.pluck(:destination_airport_id)).uniq
    route_hash = Hash.new()
    Route.find_by_sql(["SELECT routes.distance_mi, airports1.iata_code AS iata1, airports2.iata_code AS iata2 FROM routes JOIN airports AS airports1 ON airports1.id = routes.airport1_id JOIN airports AS airports2 ON airports2.id = routes.airport2_id WHERE routes.airport1_id = ? OR routes.airport2_id = ?", @airport.id, @airport.id]).map{|x| route_hash[[x.iata1,x.iata2]] = x.distance_mi }
  
    @flights.each do |flight|
      trip_array.push(flight.trip_id)
      unless (flight.trip_id == prev_trip_id && flight.trip_section == prev_section_id)
        @sections.push( {:trip_id => flight.trip_id, :trip_name => flight.trip_name, :trip_section => flight.trip_section, :departure => flight.departure_date} )
      end
      prev_trip_id = flight.trip_id
      prev_section_id = flight.trip_section
      section_where_array.push("(trip_id = #{flight.trip_id.to_i} AND trip_section = #{flight.trip_section.to_i})")
      
      # Create hash of the other airports on flights to/from this airport and their counts
      if (flight.origin_iata_code == @airport.iata_code)
        pair_totals[flight.destination_iata_code] += 1
        pair_cities[flight.destination_iata_code] = flight.destination_city
        pair_countries[flight.destination_iata_code] = flight.destination_country
        pair_distances[flight.destination_iata_code] = route_hash[[flight.origin_iata_code,flight.destination_iata_code]] || route_hash[[flight.destination_iata_code,flight.origin_iata_code]] || -1
      else
        pair_totals[flight.origin_iata_code] += 1
        pair_cities[flight.origin_iata_code] = flight.origin_city
        pair_countries[flight.origin_iata_code] = flight.origin_country
        pair_distances[flight.origin_iata_code] = route_hash[[flight.origin_iata_code,flight.destination_iata_code]] || route_hash[[flight.destination_iata_code,flight.origin_iata_code]] || -1
      end
    end
    
    trip_array = trip_array.uniq.sort
    @sections.uniq!

    @trips = Flight.find_by_sql(["SELECT flights.trip_id AS id, MIN(flights.departure_date) AS departure_date, name, hidden FROM flights INNER JOIN trips on trips.id = flights.trip_id WHERE flights.trip_id IN (?) GROUP BY flights.trip_id, name, hidden ORDER BY departure_date", trip_array])
    
    @trips_using_airport_flights = Flight.flights_table.where(:trip_id => trip_array)
    @sections_using_airport_flights = Flight.flights_table.where(section_where_array.join(' OR '))

    @airport_frequency = Airport.frequency_hash(@flights)[@airport.id]
   
    @pair_maximum = pair_totals.length > 0 ? pair_totals.values.max : 1
 
    # Create direct flight airport array sorted by count descending, city ascending:
    pair_totals.each do |airport, count|
      @direct_flight_airports << {:iata_code => airport, :total_flights => count, :city => pair_cities[airport], :distance_mi => pair_distances[airport], :country => pair_countries[airport]}
    end
    
    # Find maxima for graph scaling:
    @flights_maximum = @flights.length == 0 ? 0 : @direct_flight_airports.max_by{|i| i[:total_flights].to_i}[:total_flights]
    @distance_maximum = @flights.length == 0 ? 0 : @direct_flight_airports.max_by{|i| i[:distance_mi].to_i}[:distance_mi]
    
    # Sort city pair table:
    sort_params = sort_parse(params[:sort], %w(flights city code distance), :desc)
    @sort_cat   = sort_params[:category]
    @sort_dir   = sort_params[:direction]
    sort_mult   = (@sort_dir == :asc ? 1 : -1)
    
    case @sort_cat
    when :city
      @direct_flight_airports = @direct_flight_airports.sort_by {|value| value[:city]}
      @direct_flight_airports.reverse! if @sort_dir == :desc
    when :code
      @direct_flight_airports = @direct_flight_airports.sort_by {|value| value[:iata_code]}
      @direct_flight_airports.reverse! if @sort_dir == :desc
    when :flights
      @direct_flight_airports = @direct_flight_airports.sort_by {|value| [sort_mult*value[:total_flights],value[:city]]}
    when :distance
      @direct_flight_airports = @direct_flight_airports.sort_by {|value| [sort_mult*value[:distance_mi],value[:city]]}
    end
    
    # Create comparitive lists of airlines, aircraft, and classes:
    airline_frequency(@flights)
    operator_frequency(@flights)
    aircraft_frequency(@flights)
    class_frequency(@flights)
    
    # Create maps:
    @region = current_region(default: :world)
    @airport_map  = FlightsMap.new(@flights, highlighted_airports: [@airport.iata_code], region: @region)
    @sections_map = FlightsMap.new(@sections_using_airport_flights, highlighted_airports: [@airport.iata_code], region: @region)
    @trips_map    = FlightsMap.new(@trips_using_airport_flights, highlighted_airports: [@airport.iata_code], region: @region)
    
    @title = @airport.iata_code
    @meta_description = "Maps and lists of Paul Bogardʼs flights through #{@airport.iata_code} – #{@airport.city}."
    
    add_breadcrumb 'Airports', 'airports_path'
    add_breadcrumb @title, "airport_path(@airport.iata_code)"
  rescue ActiveRecord::RecordNotFound
    flash[:record_not_found] = "We couldnʼt find an airport with an ID of #{params[:id]}. Instead, weʼll give you a list of airports."
    redirect_to airports_path
  end
  
  
  def new
    @title = "New Airport"
    add_breadcrumb 'Airports', 'airports_path'
    add_breadcrumb 'New Airport', 'new_airport_path'
    @airport = Airport.new
  end
  
  
  def create
    @airport = Airport.new(airport_params)
    if @airport.save
      flash[:success] = "Successfully added #{params[:airport][:iata_code]}!"
      redirect_to @airport
    else
      render 'new'
    end
  end
  
  
  def edit
    @airport = Airport.find(params[:id])
    add_breadcrumb 'Airports', 'airports_path'
    add_breadcrumb @airport.iata_code, 'airport_path(@airport)'
    add_breadcrumb 'Edit Airport', 'edit_airport_path(@airport)'
  end
  
  
  def update
    @airport = Airport.find(params[:id])
    if @airport.update_attributes(airport_params)
      flash[:success] = "Successfully updated airport."
      redirect_to @airport
    else
      render 'edit'
    end
  end
  
  
  def destroy
    @flights = Flight.where("origin_airport_id = :airport_id OR destination_airport_id = :airport_id", {:airport_id => params[:id]})
    if @flights.any?
      flash[:error] = "This airport still has flights and could not be deleted. Please delete all of this airportʼs flights first."
      redirect_to airport_path(params[:id])
    else
      if (Airport.exists?(params[:id]))
        Airport.find(params[:id]).destroy
      else
        Airport.where(:iata_code => params[:id]).first.destroy
      end
      flash[:success] = "Airport destroyed."
      redirect_to airports_path
    end
  end
  
  
  private
  
    def airport_params
      params.require(:airport).permit(:city, :iata_code, :country, :region_conus)
    end
  
    # Take a collection of flights, and return an array of all airport IDs
    # associated with those flights.
    # Params:
    # +flights+:: A collection of Flights.
    def airports_with_flights(flights)
      airport_ids = Array.new
      flights.each do |flight|
        airport_ids.push(flight[:origin_airport_id])
        airport_ids.push(flight[:destination_airport_id])
      end
      return airport_ids.uniq.sort
    end
  
end
