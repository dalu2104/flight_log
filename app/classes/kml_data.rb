class KMLData
  include ActionView::Helpers
  include ActionView::Context

  # Initialize a KML file.
  # Params:
  # +flights+:: A collection of Flight objects
  def initialize(flights: nil)
    @flights = flights
    if flights
      @routes = flights.includes(:origin_airport, :destination_airport).map{|f| [f.origin_airport.iata_code, f.destination_airport.iata_code].sort}.uniq
      @airports = airports(flights)
    end
  end

  # Return the XML for a KML document.
  def xml
    return nil unless @flights
    output = %Q(<?xml version="1.0" encoding="UTF-8" ?>).html_safe
    output += content_tag(:kml, xmlns: "http://www.opengis.net/kml/2.2") do
      content_tag(:Document) do
        concat content_tag(:name, "Flights")
        concat content_tag(:description, "Paul Bogard’s Flight History")
        concat kml_styles
        concat kml_camera
        concat content_tag(:open, "1")
        concat kml_airports(@airports)
      end
    end
    return output
  end

  private

  # Given a collection of flights, return an array of airport details hashes (IATA codes as keys; city, latitude, longitude as values)
  # Params:
  # +flights+:: A collection of Flight objects
  def airports(flights)
    airport_ids = flights.pluck(:origin_airport_id, :destination_airport_id).flatten.uniq.sort
    airport_details = Airport.find(airport_ids).pluck(:iata_code, :city, :latitude, :longitude).sort_by{|x| x[0]}
    airport_hash = Hash.new();
    airport_details.each do |airport|
      airport_hash[airport[0]] = {city: airport[1], latitude: airport[2], longitude: airport[3] }
    end
    return airport_hash
  end

  # Create KML for a specific Airport point
  # Params:
  # +iata+:: IATA code
  # +city+:: City
  # +lat+:: Latitude
  # +lon+:: Longitude
  def kml_airport(iata, city, lat, lon)
    return content_tag(:Placemark) do
      concat content_tag(:name, iata)
      concat content_tag(:description, city)
      concat content_tag(:styleUrl, "#airportMarker")
      concat content_tag(:Point, content_tag(:coordinates, "#{lon},#{lat},0"))
    end
  end

  # Create KML for airport Points
  # Params:
  # +airports+:: An airport details hash
  def kml_airports(airports)
    return content_tag(:Folder) do
      concat content_tag(:name, "Airports")
      airports.each do |iata, details|
        concat kml_airport(iata, details[:city], details[:latitude], details[:longitude])
      end
    end
  end

  # Define KML camera
  def kml_camera
    content_tag(:Camera) do
      concat content_tag(:longitude, "-98.5795")
      concat content_tag(:latitude, "39.828175")
      concat content_tag(:altitude, "5000000")
      concat content_tag(:altitudeMode, "absolute")
    end
  end
  
  # Define KML styles
  def kml_styles
    output = content_tag(:Style, id: "airportMarker") do
      content_tag(:Icon) do
        content_tag(:href, "http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png")
      end
    end
    output += content_tag(:Style, id: "flightPath") do
      content_tag(:LineStyle) do
        concat content_tag(:color, "ff0000ff")
        concat content_tag(:width, "2")
      end
    end
  end

end