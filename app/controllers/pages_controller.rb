# Controls pages which don't fall under a specific model.
class PagesController < ApplicationController

  # Shows the front page for Flight Historian, including summaries of all {Flight Flights}.
  #
  # Includes:
  # * a {FlightsMap}
  # * the top 5 {Airport Airports}, {Airline Airlines}, {Route Routes}, {AircraftFamily AircraftFamilies}, and {TailNumber TailNumbers}
  # * the longest and shortest {Flight}
  #
  # @return [nil]
  def flightlog
    @logo_used = true
    @region = current_region(default: [])
    
    @flights = flyer.flights(current_user)
    
    @flight_aircraft = AircraftFamily.flight_table_data(@flights).reject{|aircraft| aircraft[:id].nil?}
    @flight_airlines = Airline.flight_table_data(@flights, type: :airline).reject{|airline| airline[:id].nil?}
    @flight_airports = Airport.visit_table_data(@flights)
    @flight_routes = Route.flight_table_data(@flights)
    @flight_tails = TailNumber.flight_table_data(@flights)
    
    if logged_in?
      Trip.where(hidden: true).map{|trip| add_message(:info, "Active Trip: #{view_context.link_to(trip.name, trip_path(trip), class: "title")}", "message-active-trip-#{trip.id}")} # Link to hidden trips
      add_message(:info, "You have boarding passes you can #{view_context.link_to("import", new_flight_menu_path)}!", "message-boarding-passes-available-for-import") if PKPass.any?
      if @flight_routes.find{|x| x[:distance_mi].nil?}
        add_message(:warning, "Some #{view_context.link_to("routes", routes_path)} don’t have distances.")
      end
    end
    
    @total_distance = @flights.total_distance    
    
    if @flights.any?
      @map = FlightsMap.new(@flights, region: @region)
      @route_superlatives = @flights.superlatives
    end

  end
  
  # Responds to a Let's Encrypt query. Used to renew SSL certificates.
  #
  # @return [nil]
  # @see https://letsencrypt.org Let's Encrypt
  def letsencrypt
    render plain: ENV["LETS_ENCRYPT_KEY"]
  end
  
  # Takes a {http://www.gcmap.com/ Great Circle Mapper} map
  # image and serves it from the Flight Historian server. This is needed
  # because the Great Circle Mapper is HTTP only while Flight Historian is
  # HTTPS, and browsers will give certificate errors if an HTTP image is
  # embedded in an HTTPS page.
  # 
  # In order to prevent other sites from using this proxy, this method will
  # only render an image if the parameters include a valid checksum generated
  # by {Map.hash_image_query}, and will otherwise return a Not Found error.
  #
  # Many maps will have forward slashes ("/") in the Great Circle Mapper query,
  # which gets escaped to %2F. However, this means the query will take up more
  # characters, which could be a problem with some browsers' character length
  # limit with very long queries. Thus, the proxy will accept queries with
  # underscores ("_"), which do not get escaped, in place of slashes, and will
  # convert them as appropriate. Escaped slashes will also work.
  #
  # @return [nil]
  # @see Map.hash_image_query
  # @see http://www.gcmap.com/ Great Circle Mapper
  def gcmap_image_proxy
    require "open-uri"
    
    query = params[:query].gsub("_","/")
    
    if Map.hash_image_query(query) == params[:check] # Ensure the query was issued by this application
      response.headers["Cache-Control"] = "public, max-age=#{1.year.to_i}"
      response.headers["Content-Type"] = "image/gif"
      response.headers["Content-Disposition"] = "inline"
      image_url = "http://www.gcmap.com/map?PM=#{params[:airport_options]}&MP=r&MS=wls2&P=#{query}"
      render body: URI.open(image_url, "rb").read
    else
      raise ActionController::RoutingError.new("Not Found")
    end
    
  rescue SocketError
  end

end