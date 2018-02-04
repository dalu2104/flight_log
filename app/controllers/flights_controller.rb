class FlightsController < ApplicationController
  protect_from_forgery except: :show_boarding_pass_json
  before_action :logged_in_user, :only => [:new, :create, :create_iata, :edit, :update, :destroy, :index_emails, :create_iata]
  add_breadcrumb "Home", "root_path"
  
  def index
    add_breadcrumb "Flights", "flights_path"
    @logo_used = true
    @title = "Flights"
    @region = current_region(default: [])
    
    @flights = flyer.flights(current_user).includes(:airline, :origin_airport, :destination_airport, :trip)
        
    @year_range = @flights.year_range
    
    if @flights.any?
    
      @map = FlightsMap.new(@flights, region: @region)
      
      @total_distance = total_distance(@flights)
    
      # Determine which years have flights:
      @years_with_flights = Hash.new(false)
      @flights.each do |flight|
        @years_with_flights[flight.departure_date.year] = true
      end
      @meta_description = "Maps and lists of all of Paul Bogardʼs flights."
    
      # Sort flight table:
      sort_params = sort_parse(params[:sort], %w(departure), :asc)
      @sort_cat   = sort_params[:category]
      @sort_dir   = sort_params[:direction]
      @flights = @flights.reverse_order if @sort_dir == :desc
    
    end
  
  end
  
  def show
    @logo_used = true
    @flight = flyer.flights(current_user).find(params[:id])

    @title = @flight.airline.airline_name + " " + @flight.flight_number.to_s
    @meta_description = "Details for Paul Bogardʼs #{@flight.airline.airline_name} #{@flight.flight_number} flight on #{Flight.format_date(@flight.departure_date)}."
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb @title, "flight_path(#{params[:id]})"
    add_admin_action view_context.link_to("Delete Flight", :flight, :method => :delete, :data => {:confirm => "Are you sure you want to delete this flight?"}, :class => "warning")
    add_admin_action view_context.link_to("Edit Flight", edit_flight_path(@flight))
    
    if @flight.trip.hidden? && logged_in?
      add_message(:warning, "This flight is part of a #{view_context.link_to("hidden trip", trip_path(@flight.trip))}!")
      check_email_for_boarding_passes
    end
    
    updated_pass = PKPass.where(flight_id: @flight)
    if updated_pass.any?
      add_message(:info, "This flight has an #{view_context.link_to("updated boarding pass", edit_flight_with_pass_path(pass_id: updated_pass.first))} available!")
    end
    
    @map = SingleFlightMap.new(@flight)
    @route_distance = Route.distance_by_airport_id(@flight.origin_airport, @flight.destination_airport)
    @boarding_pass = BoardingPass.new(@flight.boarding_pass_data, flight: @flight)
    
  rescue ActiveRecord::RecordNotFound
    flash[:warning] = "We couldnʼt find a flight with an ID of #{params[:id]}. Instead, weʼll give you a list of flights."
    redirect_to flights_path
  end
    
  def show_date_range
    add_breadcrumb "Flights", "flights_path"
    @logo_used = true
    
    if params[:year].present?
      @date_range = ("#{params[:year]}-01-01".to_date)..("#{params[:year]}-12-31".to_date)
      add_breadcrumb params[:year], "flights_path(:year => #{params[:year]})"
      @date_range_text = "in #{params[:year]}"
      @flight_list_title = params[:year] + " Flight List"
      @superlatives_title = params[:year] + " Longest and Shortest Routes"
      @superlatives_title_nav = @superlatives_title.downcase
      @title = "Flights in #{params[:year]}"
      @meta_description = "Maps and lists of Paul Bogardʼs flights in #{params[:year]}"
    elsif (params[:start_date].present? && params[:end_date].present?)
      if (params[:start_date] > params[:end_date])
        raise ArgumentError.new("Start date cannot be later than end date")
      end

      @date_range = (params[:start_date].to_date)..(params[:end_date].to_date)
      add_breadcrumb "#{Flight.format_date(params[:start_date].to_date)} - #{Flight.format_date(params[:end_date].to_date)}", "flights_path(:start_date => '#{params[:start_date]}', :end_date => '#{params[:end_date]}')"
      @date_range_text = "from #{Flight.format_date(params[:start_date].to_date)} to #{Flight.format_date(params[:end_date].to_date)}"
      @flight_list_title = "Flight List for #{Flight.format_date(params[:start_date].to_date)} to #{Flight.format_date(params[:end_date].to_date)}"
      @superlatives_title = "Longest and Shortest Routes for#{Flight.format_date(params[:start_date].to_date)} to #{Flight.format_date(params[:end_date].to_date)}"
      @superlatives_title_nav = "Longest and shortest routes for#{Flight.format_date(params[:start_date].to_date)} to #{Flight.format_date(params[:end_date].to_date)}"
      @title = "Flights: #{Flight.format_date(params[:start_date].to_date)} – #{Flight.format_date(params[:end_date].to_date)}"
      @meta_description = "Maps and lists of Paul Bogardʼs flights from #{Flight.format_date(params[:start_date].to_date)} to #{Flight.format_date(params[:end_date].to_date)}"
    else
      raise ArgumentError.new("No date parameters were given for a date range")
    end
    
    @in_text = params[:year].present? ? params[:year] : "this date range"
    
    flyer_flights = flyer.flights(current_user)
    @flights = flyer_flights.where(departure_date: @date_range).includes(:airline, :origin_airport, :destination_airport, :trip)
    @year_range = flyer_flights.year_range
    @years_with_flights = flyer_flights.years_with_flights
    
    raise ActiveRecord::RecordNotFound if @flights.length == 0
    
    @region = current_region(default: [])
    @map = FlightsMap.new(@flights, region: @region)
    @total_distance = total_distance(@flights)
      
    # Create comparitive lists of airlines and classes:
    @airports = Airport.visit_count(@flights) 
    @airlines = Airline.flight_count(@flights, type: :airline) 
    @aircraft_families = AircraftFamily.flight_count(@flights)
    @classes = TravelClass.flight_count(@flights)
    @new_airports = Airport.new_in_date_range(flyer, current_user, @date_range)
    @new_airlines = Airline.new_in_date_range(flyer, current_user, @date_range)   
    @new_aircraft_families = AircraftFamily.new_in_date_range(flyer, current_user, @date_range)
    @new_classes = TravelClass.new_in_date_range(flyer, current_user, @date_range)
    
    # Create superlatives:
    @route_superlatives = superlatives(@flights)
          
  rescue ActiveRecord::RecordNotFound
    flash[:warning] = "We couldnʼt find any flights in #{@in_text}. Instead, weʼll give you a list of flights."
    redirect_to flights_path
    
  end
    
  def index_classes
    add_breadcrumb "Travel Classes", "classes_path"
    
    @flights = flyer.flights(current_user)
    @classes = TravelClass.flight_count(@flights)
    
    @title = "Travel Classes"
    @meta_description = "A count of how many times Paul Bogard has flown in each class."
    
    if @classes.any?
                
      # Sort aircraft table:
      sort_params = sort_parse(params[:sort], %w(class flights), :asc)
      @sort_cat   = sort_params[:category]
      @sort_dir   = sort_params[:direction]
      sort_mult   = (@sort_dir == :asc ? 1 : -1)
      case @sort_cat
      when :class
        @classes = @classes.sort_by { |tc| tc[:class_code] || "" }
        @classes.reverse! if @sort_dir == :desc
      when :flights
        @classes = @classes.sort_by { |tc| [sort_mult*tc[:flight_count], tc[:class_code] || ""] }
      end
      
    end
  end
  
  def show_class
    @logo_used = true
    
    @flights = flyer.flights(current_user).where(travel_class: params[:travel_class]).includes(:airline, :origin_airport, :destination_airport, :trip)
    
    @title = TravelClass.list[params[:travel_class]].titlecase + " Class"
    @meta_description = "Maps and lists of Paul Bogardʼs #{TravelClass.list[params[:travel_class]].downcase} class flights."
    raise ActiveRecord::RecordNotFound if @flights.length == 0
    add_breadcrumb "Travel Classes", "classes_path"
    add_breadcrumb TravelClass.list[params[:travel_class]].titlecase, show_class_path(params[:travel_class])

    @region = current_region(default: [])
    @map = FlightsMap.new(@flights, region: @region)
    @total_distance = total_distance(@flights)

    # Create comparitive lists of airlines, operators, and aircraft:
    @airlines = Airline.flight_count(@flights, type: :airline)
    @operators = Airline.flight_count(@flights, type: :operator)
    @aircraft_families = AircraftFamily.flight_count(@flights)

    # Create superlatives:
    @route_superlatives = superlatives(@flights)
    
  rescue ActiveRecord::RecordNotFound
    flash[:warning] = "We couldnʼt find any flights in #{@title}. Instead, weʼll give you a list of travel classes."
    redirect_to classes_path
  end

  def index_tails
    add_breadcrumb "Tail Numbers", "tails_path"
    
    @title = "Tail Numbers"
    @meta_description = "A list of the individual airplanes Paul Bogard has flown on, and how often heʼs flown on each."
    
    @tail_numbers_table = Array.new
          
    @flights = flyer.flights(current_user)
    @tail_numbers_table = TailNumber.flight_count(@flights)
  
    # Find maxima for graph scaling:
    @flights_maximum = @tail_numbers_table.max_by{|i| i[:count]}[:count]
  
    # Sort tails table:
    sort_params = sort_parse(params[:sort], %w(flights tail aircraft airline), :desc)
    @sort_cat   = sort_params[:category]
    @sort_dir   = sort_params[:direction]
    sort_mult   = (@sort_dir == :asc ? 1 : -1)
    case @sort_cat
    when :tail
      @tail_numbers_table = @tail_numbers_table.sort_by {|tail| tail[:tail_number]}
      @tail_numbers_table.reverse! if @sort_dir == :desc
    when :flights
      @tail_numbers_table = @tail_numbers_table.sort_by {|tail| [sort_mult*tail[:count], tail[:tail_number]]}
    when :aircraft
      @tail_numbers_table = @tail_numbers_table.sort_by {|tail| [tail[:aircraft], tail[:airline_name]]}
      @tail_numbers_table.reverse! if @sort_dir == :desc
    when :airline
      @tail_numbers_table = @tail_numbers_table.sort_by {|tail| [tail[:airline_name], tail[:aircraft]]}
      @tail_numbers_table.reverse! if @sort_dir == :desc
    end
      
  end
  
  def show_tail
    @logo_used = true
    @flights = flyer.flights(current_user).where(tail_number: params[:tail_number]).includes(:airline, :origin_airport, :destination_airport, :trip)
    
    raise ActiveRecord::RecordNotFound if @flights.length == 0
    @title = params[:tail_number]
    @meta_description = "Maps and lists of Paul Bogardʼs flights on tail number #{params[:tail_number]}."
    add_breadcrumb "Tail Numbers", "tails_path"
    add_breadcrumb @title, show_tail_path(params[:tail_number])
    
    @region = current_region(default: [])
    @map = FlightsMap.new(@flights, region: @region)
    @total_distance = total_distance(@flights)
    
    # Create comparitive list of airlines, operators, and classes:
    @airlines = Airline.flight_count(@flights, type: :airline)
    @operators = Airline.flight_count(@flights, type: :operator)
    @classes = TravelClass.flight_count(@flights)
    
    # Create superlatives:
    @route_superlatives = superlatives(@flights)
    
  rescue ActiveRecord::RecordNotFound
   flash[:warning] = "We couldnʼt find any flights with the tail number #{params[:tail_number]}. Instead, weʼll give you a list of tail numbers."
    redirect_to tails_path
  end
  
  def input_boarding_pass
    @title = "Boarding Pass Parser"
    @meta_description = "A boarding pass barcode parser."
    add_breadcrumb @title, boarding_pass_path
  end
  
  def build_boarding_pass
    if params[:data].present?
      redirect_to show_boarding_pass_path(params[:data])
    else
      flash[:error] = "Boarding pass data cannot be blank."
      redirect_to boarding_pass_path
    end
  end
  
  def show_boarding_pass
    @title = "Boarding Pass Results"
    @meta_description = "Results from the boarding pass barcode parser."
    add_breadcrumb "Boarding Pass", boarding_pass_path
    
    @boarding_pass = BoardingPass.new(params[:data])
    #if @boarding_pass.leg_operating_carrier_designator(0)
    if @boarding_pass.data.dig(:repeated, 0, :mandatory, 42)
      bp_string = "#{@boarding_pass.data.dig(:repeated, 0, :mandatory, 42, :raw)} #{@boarding_pass.data.dig(:repeated, 0, :mandatory, 43, :raw)} #{@boarding_pass.data.dig(:repeated, 0, :mandatory, 26, :raw)} ✈ #{@boarding_pass.data.dig(:repeated, 0, :mandatory, 38, :raw)}"
      @title += ": #{bp_string}"
      add_breadcrumb bp_string, boarding_pass_path
    else
      add_breadcrumb "Results", boarding_pass_path
    end
    
  end
  
  def show_boarding_pass_json
    boarding_pass = BoardingPass.new(params[:data])
    if params[:callback]
      render :json => boarding_pass.data, :callback => params[:callback]
    else
      render :json => boarding_pass.data
    end
  end

  def flightxml_lookup
    @title = "FlightXML Lookup"
    @meta = "Look up a flight on FlightAware"
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb "FlightXML Lookup", "flightxml_lookup_path"
  end
  
  def flightxml_select_flight
    if session[:ident]
      @ident = session[:ident]
    elsif params[:airline_icao] && params[:flight_number]
      @ident = [params[:airline_icao], params[:flight_number]].join
      session[:flight_number] = params[:flight_number]
      session[:airline_icao] = params[:airline_icao]
    end
    
    @flights = @ident ? FlightXML.flight_lookup(@ident) : nil
    
    if @flights && @flights.any?
      origins = @flights.map{|f| f[:origin]}
      destinations = @flights.map{|f| f[:destination]}
      @timezones = FlightXML.airport_timezones(origins | destinations)
    end

    @title = "Select Flight"
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb "New Flight", "new_flight_menu_path"
    add_breadcrumb [params[:airline_icao],params[:flight_number]].join, "flightxml_select_flight_path"
    render :flightxml_select_flight
  end
  
  # Shows a set of forms to allow the user to choose how they will enter their new flight.
  def new_flight_menu
    @title = "Create a New Flight"
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb "New Flight", "new_flight_menu_path"
    clear_new_flight_variables
    
    # Determine an appropriate trip to use:
    begin
      @trip = Trip.find(params[:trip_id])
    rescue ActiveRecord::RecordNotFound
      if Trip.where(hidden: true).any?
        @trip = Trip.where(hidden: true).order(:created_at).last
      elsif Trip.any?
        @trip = Trip.order(:created_at).last
      else
        flash[:warning] = "You have no trips to put a flight in, so we can’t create a new flight. Please create a trip."
        redirect_to new_trip_path
      end
    end
    empty_trips = Trip.with_no_flights.map{|trip| [trip.name, trip.id]}
    @trips = empty_trips.concat(Trip.with_departure_dates(current_user, current_user).reverse.map{|trip| ["#{trip.name} / #{Flight.format_date(trip.departure_date)}", trip.id]})
    
    # Get PKPasses:
    check_email_for_boarding_passes
    @passes = PKPass.pass_summary_list
        
  end
  
  # Changes the trip on the new_flight_menu
  def change_trip
    redirect_to new_flight_menu_path(trip_id: params[:trip_id])
  end
  
  # Extracts flight info from BCBP data and passes it along to select a flight
  def process_bcbp
    pass = BoardingPass.new(params[:bcbp])
    session[:bcbp] = params[:bcbp]
    error_message = "We could not determine the airline and flight number from the boarding pass barcode data you provided."
    if pass.is_valid?
      airline_iata = pass.summary_fields[:airline]
      flight_number = pass.summary_fields[:flight]
      if airline_iata && flight_number
        airline_icao = Airline.convert_iata_to_icao(airline_iata)
        redirect_to flightxml_select_flight_path(airline_icao: airline_icao, flight_number: flight_number, trip_id: params[:trip_id])
      else
        flash[:error] = error_message
        redirect_to new_flight_menu_path(trip_id: params[:trip_id])
      end
    else
      flash[:error] = error_message
      redirect_to new_flight_menu_path(trip_id: params[:trip_id])
    end
    
  end
  
  def new
    @title = "New Flight"
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb "New Flight", "new_flight_menu_path"
    
    session[:new_flight] ||= Hash.new
    
    trip = Trip.find(params[:trip_id])
    trip_has_existing_flights = (trip.flights.size > 0) # Must check before creating new flight
    @flight = trip.flights.new
    
=begin    
    add_breadcrumb "Enter Flight Data", "new_flight_path"
    
    trip = Trip.find(params[:trip_id])
    trip_has_existing_flights = (trip.flights.size > 0) # Must check before creating new flight
    @flight = trip.flights.new
    @pass = PKPass.find_by(id: params[:pass_id])
    departure_date = params[:departure_date] ? Date.parse(params[:departure_date]) : nil
    
    if session[:lookup_fields]
      @lookup_fields = session[:lookup_fields]
      if params[:faflightid]
        flightxml_data = FlightXML.form_values(params[:faflightid])
        if flightxml_data
          @lookup_fields.merge!(flightxml_data)
          @lookup_fields.store(:departure_date, departure_date) if departure_date
        else
          @lookup_fields.store(:error, FlightXML::ERROR)
        end
      end
    else
      # Prefill fields based on any known flight information:
      @lookup_fields = Flight.lookup_form_fields(
        pk_pass: @pass,
        bcbp_data: session[:bcbp],
        fa_flight_id: params[:faflightid],
        departure_date: departure_date,
        airline_icao: session[:airline_icao],
        flight_number: session[:flight_number]
      )
    end
    
    if @pass && @lookup_fields[:ident] && @lookup_fields[:fa_flight_id].nil?
      session[:ident] = @lookup_fields[:ident]
      redirect_to flightxml_select_flight_path(trip_id: params[:trip_id])
    end
    
    id_fields = get_or_create_ids_from_codes(@lookup_fields)
    @lookup_fields.merge!(id_fields) if id_fields
    
    # Guess trip section:
    if trip_has_existing_flights
      last_flight = trip.flights.chronological.last
      departure_utc = @lookup_fields.dig(:departure_utc)
      if departure_utc && departure_utc >= last_flight.departure_utc + 1.day
        @default_trip_section = last_flight.trip_section + 1
      else
        @default_trip_section = last_flight.trip_section
      end
    else
      @default_trip_section = 1
    end
    
    add_message(:warning, @lookup_fields[:error]) if @lookup_fields[:error]
=end
        
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "We could not find a trip with an ID of #{params[:trip_id]}. Please select another trip."
    redirect_to new_flight_menu_path
    
  end
  
  def create
    @flight = Trip.find(params[:flight][:trip_id]).flights.new(flight_params)
    if @flight.save
      flash[:success] = "Successfully added #{@flight.airline.airline_name} #{@flight.flight_number}."
      if (@flight.tail_number.present? && Flight.where(:tail_number => @flight.tail_number).count > 1)
        flash[:success] += " Youʼve had prior flights on this tail!"
      end
      if (@flight.departure_date.to_time - @flight.departure_utc.to_time).to_i.abs > 60*60*24*2
        flash[:warning] = "Your departure date and UTC time are more than a day apart &ndash; are you sure theyʼre correct?".html_safe
      end
      # If pass exists, delete pass 
      if params[:flight][:pass_id]
        pass = PKPass.find(params[:flight][:pass_id])
        pass.destroy if pass
      end
      redirect_to @flight
    else
      render "new"
    end
  end
  
  def edit
    @flight = Flight.find(params[:id])
    add_breadcrumb "Flights", "flights_path"
    add_breadcrumb "#{@flight.airline.airline_name} #{@flight.flight_number}", "flight_path(@flight)"
    add_breadcrumb "Edit Flight", "edit_flight_path(@flight)"
    @title = "Edit Flight"
  end
  
  def update
    @flight = Flight.find(params[:id])
    if @flight.update_attributes(flight_params)
      flash[:success] = "Successfully updated flight."
      if (@flight.tail_number.present? && Flight.where(:tail_number => @flight.tail_number).count > 1)
        flash[:success] += " You’ve had prior flights on this tail!"
      end
      if (@flight.departure_date.to_time - @flight.departure_utc.to_time).to_i.abs > 60*60*24*2
        flash[:warning] = "Your departure date and UTC time are more than a day apart &ndash; are you sure they’re correct?".html_safe
      end
      @pass = PKPass.find_by(id: params[:flight][:pass_id])
      @pass.destroy if @pass
      
      redirect_to @flight
    else
      render "edit"
    end
  end
    
  def destroy
    flight = Flight.find(params[:id])
    trip = flight.trip
    flight.destroy
    flash[:success] = "Flight destroyed."
    redirect_to trip
  end
    
  private
    
    # Clears all session variables associated with creating a new flight.
    def clear_new_flight_variables
      session[:airline_icao]  = nil
      session[:bcbp]          = nil
      session[:flight_number] = nil
      session[:ident]         = nil
      session[:lookup_fields] = nil
    end
    
    def flight_params
      params.require(:flight).permit(:aircraft_family_id, :aircraft_name, :airline_id, :boarding_pass_data, :codeshare_airline_id, :codeshare_flight_number, :comment, :departure_date, :departure_utc, :destination_airport_id, :fleet_number, :flight_number, :operator_id, :origin_airport_id, :tail_number, :travel_class, :trip_id, :trip_section)
    end
      
    # Accepts a hash of form fields, and uses ICAO or IATA codes to determine
    # AircraftFamily, Airline, and Airport IDs, returning them in a hash. If
    # any ICAO or IATA codes are not found, this method redirects to a form
    # allowing the user to create new AircraftFamilies, Airlines, or Airports
    # as needed.
    def get_or_create_ids_from_codes(fields)
      
      ids = Hash.new
      session[:lookup_fields] = fields
      
      # AIRPORTS
      
      if fields[:origin_airport_id].blank? && (fields[:origin_airport_icao] || fields[:origin_airport_iata])
        if fields[:origin_airport_icao] && origin_airport = Airport.find_by(icao_code: fields[:origin_airport_icao])
          ids.store(:origin_airport_id, origin_airport.id)
        elsif fields[:origin_airport_iata] && origin_airport = Airport.find_by(iata_code: fields[:origin_airport_iata])
          ids.store(:origin_airport_id, origin_airport.id)
        else
          input_new_undefined_airport(fields[:origin_airport_iata], fields[:origin_airport_icao])
          return
        end
      end
      
      if fields[:destination_airport_id].blank? && (fields[:destination_airport_icao] || fields[:destination_airport_iata])
        if fields[:destination_airport_icao] && destination_airport = Airport.find_by(icao_code: fields[:destination_airport_icao])
          ids.store(:destination_airport_id, destination_airport.id)
        elsif fields[:destination_airport_iata] && destination_airport = Airport.find_by(iata_code: fields[:destination_airport_iata])
          ids.store(:destination_airport_id, destination_airport.id)
        else
          input_new_undefined_airport(fields[:destination_airport_iata], fields[:destination_airport_icao])
          return
        end
      end
      
      # AIRCRAFT FAMILIES
      
      if fields[:aircraft_family_id].blank? && fields[:aircraft_family_icao]
        if fields[:aircraft_family_icao] && aircraft_family = AircraftFamily.find_by(icao_aircraft_code: fields[:aircraft_family_icao])
          ids.store(:aircraft_family_id, aircraft_family.id)
        else
          input_new_undefined_aircraft_family(fields[:aircraft_family_icao])
          return
        end
      end
      
      # AIRLINES
      
      if fields[:airline_id].blank? && (fields[:airline_icao] || fields[:airline_iata])
        if fields[:airline_icao] && airline = Airline.find_by(icao_airline_code: fields[:airline_icao])
          ids.store(:airline_id, airline.id)
        elsif fields[:airline_iata] && airline = Airline.find_by(iata_airline_code: fields[:airline_iata])
          ids.store(:airline_id, airline.id)
        else
          input_new_undefined_airline(fields[:airline_iata], fields[:airline_icao])
          return
        end
      end
      
      if fields[:operator_id].blank? && fields[:operator_icao]
        if fields[:operator_icao] && operator = Airline.find_by(icao_airline_code: fields[:operator_icao])
          ids.store(:operator_id, operator.id)
        else
          input_new_undefined_airline(nil, fields[:operator_icao])
          return
        end
      end
      
      if fields[:codeshare_airline_id].blank? && fields[:codeshare_airline_iata]
        if fields[:codeshare_airline_iata] && codeshare_airline = Airline.find_by(icao_airline_code: fields[:codeshare_airline_iata])
          ids.store(:codeshare_airline_id, codeshare_airline.id)
        else
          input_new_undefined_airline(fields[:codeshare_airline_iata], nil)
          return
        end
      end
                        
      return ids
      
    end
    
    def input_new_undefined_airport(iata, icao)
      @airport = Airport.new
      @title = "New Flight - Undefined Airport"
      @lookup_fields = {iata_code: iata, icao_code: icao}
      session[:form_location] = Rails.application.routes.recognize_path(request.original_url)
      render "new_undefined_airport"
    end
    
    def input_new_undefined_aircraft_family(icao)
      @aircraft_family = AircraftFamily.new
      @title = "New Flight - Undefined Aircraft Family"
      @lookup_fields = {icao_code: icao}
      session[:form_location] = Rails.application.routes.recognize_path(request.original_url)
      render "new_undefined_aircraft_family"
    end
    
    def input_new_undefined_airline(iata, icao)
      @airline = Airline.new
      @title = "New Flight - Undefined Airline"
      @lookup_fields = {iata_code: iata, icao_code: icao}
      session[:form_location] = Rails.application.routes.recognize_path(request.original_url)
      render "new_undefined_airline"
    end
    
    
end
