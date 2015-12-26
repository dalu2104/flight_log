class AirlinesController < ApplicationController
  before_filter :logged_in_user, :only => [:new, :create, :edit, :update, :destroy]
  add_breadcrumb 'Home', 'root_path'
  
  def index
    @logo_used = true
    add_breadcrumb 'Airlines', 'airlines_path'
    if logged_in?
      @flight_airlines = Flight.where("airline_id IS NOT NULL").group("airline_id").count
      @flight_operators = Flight.where("operator_id IS NOT NULL").group("operator_id").count
    else # Filter out hidden trips for visitors
      @flight_airlines = Flight.visitor.where("airline_id IS NOT NULL").group("airline_id").count
      @flight_operators = Flight.visitor.where("operator_id IS NOT NULL").group("operator_id").count
    end
    used_airline_ids = (@flight_airlines.keys + @flight_operators.keys).uniq
    @airlines_with_no_flights = Airline.where("id NOT IN (?)", used_airline_ids).order(:airline_name) #UPDATE
    
    
    
    @title = "Airlines"
    @meta_description = "A list of the airlines on which Paul Bogard has flown, and how often he's flown on each."
    
    @airlines_array = Array.new
    @operators_array = Array.new
    
    if (@flight_airlines.any? || @flight_operators.any?)
      
      airline_details = Airline.select("id, iata_airline_code, airline_name").find(used_airline_ids)
      airline_names = Hash.new
      airline_iata_codes = Hash.new
      airline_details.each do |airline|
        airline_names[airline.id] = airline.airline_name
        airline_iata_codes[airline.id] = airline.iata_airline_code 
      end
      
      # Set values for sort:
      case params[:sort_category]
      when "airline"
        @sort_cat = :airline
      when "code"
        @sort_cat = :code
      when "flights"
        @sort_cat = :flights
      else
        @sort_cat = :flights
      end
    
      case params[:sort_direction]
      when "asc"
        @sort_dir = :asc
      when "desc"
        @sort_dir = :desc
      else
        @sort_dir = :desc
      end
    
      sort_mult = (@sort_dir == :asc ? 1 : -1)
      
      # Prepare airline list:
      @flight_airlines.each do |airline, count| 
        @airlines_array.push({name: airline_names[airline], iata_code: airline_iata_codes[airline], count: count})
      end
    
      # Prepare operator list:
      @flight_operators.each do |operator, count|
        @operators_array.push({name: airline_names[operator], iata_code: airline_iata_codes[operator], :count => count})
      end
      
      # Find maxima for graph scaling:
      @airlines_maximum = @airlines_array.any? ? @airlines_array.max_by{|i| i[:count]}[:count] : 0
      @operators_maximum = @operators_array.any? ? @operators_array.max_by{|i| i[:count]}[:count] : 0
    
      # Sort airline and operator tables:
      case @sort_cat
      when :airline
        @airlines_array = @airlines_array.sort_by { |airline| airline[:name].downcase }
        @operators_array = @operators_array.sort_by { |operator| operator[:name].downcase }
        @airlines_array.reverse! if @sort_dir == :desc
        @operators_array.reverse! if @sort_dir == :desc
      when :code
        @airlines_array = @airlines_array.sort_by { |airline| airline[:iata_code].downcase }
        @operators_array = @operators_array.sort_by { |operator| operator[:iata_code].downcase }
        @airlines_array.reverse! if @sort_dir == :desc
        @operators_array.reverse! if @sort_dir == :desc
      when :flights
        @airlines_array = @airlines_array.sort_by { |airline| [sort_mult*airline[:count], airline[:name].downcase] }
        @operators_array = @operators_array.sort_by { |operator| [sort_mult*operator[:count], operator[:name].downcase] }
      end
    end
    
    
  end
  
  def show
    @airline = Airline.where(:iata_airline_code => params[:id]).first
    raise ActiveRecord::RecordNotFound if (@airline.nil?) #all_flights will fail if code does not exist, so check here.    
    @flights = @airline.all_flights(logged_in?)
    raise ActiveRecord::RecordNotFound if (!logged_in? && @flights.length == 0)
    
    @title = @airline.airline_name
    @logo_used = true
    add_breadcrumb 'Airlines', 'airlines_path'
    add_breadcrumb @title, "airline_path(@airline.iata_airline_code)"
    
    # Calculate total flight distance:
    @total_distance = total_distance(@flights)
    
    # Create comparitive lists of aircraft and classes:
    aircraft_frequency(@flights)
    class_frequency(@flights)
    
    # Create superlatives:
    @route_superlatives = superlatives(@flights)
    
    rescue ActiveRecord::RecordNotFound
      flash[:record_not_found] = "We couldn't find an airline with an IATA code of #{params[:id]}. Instead, we'll give you a list of airlines."
      redirect_to airlines_path
      
  end
  
  def show_operator
    @operator = Airline.where(:iata_airline_code => params[:operator]).first
    raise ActiveRecord::RecordNotFound if (@operator.nil?) #all_flights will fail if code does not exist, so check here.
    @flights = Flight.where(:operator_id => @operator.id).chronological
    @flights = @flights.visitor if !logged_in? # Filter out hidden trips for visitors
    raise ActiveRecord::RecordNotFound if (!logged_in? && @flights.length == 0)
 
    @title = @operator.airline_name + " (Operator)"
    @meta_description = "Maps and lists of Paul Bogard's flights operated by #{@operator.airline_name}."
    @logo_used = true
    add_breadcrumb 'Airlines', 'airlines_path'
    add_breadcrumb 'Flights Operated by ' + @operator.airline_name, show_operator_path(@operator.iata_airline_code)
    
    @total_distance = total_distance(@flights)
    
    # Create comparitive lists of airlines, aircraft and classes:
    airline_frequency(@flights)
    aircraft_frequency(@flights)
    class_frequency(@flights)
    
    # Create superlatives:
    @route_superlatives = superlatives(@flights)
    
    # Create list of fleet numbers and aircraft families:
    @fleet_family = Hash.new
    @fleet_name = Hash.new
    @flights.each do |flight|
      if flight.fleet_number
        @fleet_family[flight.fleet_number] = flight.aircraft_family
        @fleet_name[flight.fleet_number] = flight.aircraft_name
      end
    end
    @fleet_family = @fleet_family.sort_by{ |key, value| key }
        
  rescue ActiveRecord::RecordNotFound
    flash[:record_not_found] = "We couldn't find any flights operated by #{params[:operator]}. Instead, we'll give you a list of airlines and operators."
    redirect_to airlines_path
  end
  
  def show_fleet_number
    @operator = Airline.where(:iata_airline_code => params[:operator]).first
    @fleet_number = params[:fleet_number]
    
    @flights = Flight.where(:operator_id => @operator.id, :fleet_number => @fleet_number).chronological
    @flights = @flights.visitor if !logged_in? # Filter out hidden trips for visitors
    raise ActiveRecord::RecordNotFound if @flights.length == 0
    
    @logo_used = true
    @title = @operator.airline_name + " #" + @fleet_number
    @meta_description = "Maps and lists of Paul Bogard's flights operated on #{@operator} ##{@fleet_number}."
    add_breadcrumb 'Airlines', 'airlines_path'
    add_breadcrumb 'Flights Operated by ' + @operator.airline_name, show_operator_path(@operator.iata_airline_code)
    add_breadcrumb '#' + @fleet_number, show_fleet_number_path(@operator.iata_airline_code, @fleet_number)
    
    @total_distance = total_distance(@flights)
    
    # Create comparitive lists of airlines, aircraft and classes:
    airline_frequency(@flights)
    aircraft_frequency(@flights)
    class_frequency(@flights)
    
    # Create superlatives:
    @route_superlatives = superlatives(@flights)
    
  rescue ActiveRecord::RecordNotFound
    flash[:record_not_found] = "We couldn't find any flights operated by #{@operator} with fleet number ##{@fleet_number}. Instead, we'll give you a list of airlines and operators."
    redirect_to airlines_path
  end
  
  def new
    @title = "New Airline"
    add_breadcrumb 'Airlines', 'airlines_path'
    add_breadcrumb 'New Airline', 'new_airline_path'
    @airline = Airline.new
  end
  
  def create
    @airline = Airline.new(airline_params)
    if @airline.save
      flash[:success] = "Successfully added #{params[:airline][:airline_name]}!"
      if @airline.is_only_operator
        redirect_to show_operator_path(@airline.iata_airline_code)
      else
        redirect_to airline_path(@airline.iata_airline_code)
      end
    else
      render 'new'
    end
  end
  
  def edit
    @airline = Airline.find(params[:id])
    add_breadcrumb 'Airlines', 'airlines_path'
    add_breadcrumb @airline.airline_name, 'airline_path(@airline.iata_airline_code)'
    add_breadcrumb 'Edit Airline', 'edit_airport_path(@airline)'
  end
  
  def update
    @airline = Airline.find(params[:id])
    if @airline.update_attributes(airline_params)
      flash[:success] = "Successfully updated airline."
      if @airline.is_only_operator
        redirect_to show_operator_path(@airline.iata_airline_code)
      else
        redirect_to airline_path(@airline.iata_airline_code)
      end
    else
      render 'edit'
    end
  end
  
  def destroy
    if (Airline.exists?(params[:id]))
      @airline = Airline.find(params[:id])
    else
      @airline = Airline.where(:iata_airport_code => params[:id]).first
    end
    @flights = @airline.all_flights(true)
    if @flights.any?
      flash[:error] = "This airline still has flights and could not be deleted. Please delete all of this airline's flights first."
      redirect_to airline_path(params[:id])
    else
      @airline.destroy
      flash[:success] = "Airline deleted."
      redirect_to airlines_path
    end
  end
  
  private
  
    def airline_params
      params.require(:airline).permit(:iata_airline_code, :airline_name, :is_only_operator)
    end
  
    def logged_in_user
      redirect_to root_path unless logged_in?
    end
  
end