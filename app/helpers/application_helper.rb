# Defines helper methods for the entire application.
module ApplicationHelper

  # Adds a link to the admin block.
  #
  # @param link [ActiveSupport::SafeBuffer] a link_to object
  # @return [nil]
  def add_admin_action(link)
    @admin_actions ||= Array.new
    @admin_actions.push(link)
  end
  
  # Returns a title defined in a view's provide(:title) or content_for(:title),
  # or a default title if a title is not provided.
  #
  # @return [ActiveSupport::SafeBuffer] HTML for a <title> tag
  def title_tag
    base_title = "Paul Bogardʼs Flight Historian"
    return content_tag(:title, [content_for(:title), base_title].compact.join(" – "))
  end  
  
  # Returns a description <meta> tag with content provided by a view's
  # provide(:meta_description) or content_for(:meta_description), or a default
  # meta description if a meta description is not provied.
  #
  # @return [ActiveSupport::SafeBuffer] HTML for a <meta> tag
  def meta_description_tag
    default_description = "Paul Bogardʼs Flight Historian shows maps and tables for various breakdowns of Paulʼs flight history."
    description = content_for?(:meta_description) ? content_for(:meta_description) : default_description
    return content_tag(:meta, nil, name: "description", content: description)
  end
  
  # Formats the airport name portion of an city name. Anything contained
  # between a pair of parentheses is considered the airport name. Not all
  # cities will have airport names; airport names are only used for
  # disambiguation when a city has multiple airports.
  # 
  # @param city_airport_name [String] a city name which may or may not contain
  #   an airport name.
  # @return [ActiveSupport::SafeBuffer] A city name with any present airport
  #   name formatted.
  def format_airport_name(city_airport_name)
    return sanitize(city_airport_name.gsub(/\(.*\)/, '&ensp;<small class="airport-name">\0</small>').tr("()",""))
  end
  
  # Formats a pair of decimal coordinates into a string pair of coordinates
  # with cardinal directions and 5 decimal places.
  # 
  # @param coordinates [Array<Number>] an array containing latitude and
  #   longitude, each in decimal degrees.
  # @return [ActiveSupport::SafeBuffer] a string pair of decimal degree
  #   coordinates with N/S and E/W hemispheres and 5 decimal places.
  def format_coordinates(coordinates)
    return sanitize("#{"%.5f" % coordinates[0].abs}° #{coordinates[0] < 0 ? "S" : "N"}&ensp;#{"%.5f" % coordinates[1].abs}° #{coordinates[1] < 0 ? "W" : "E"}")
  end
  
  # Renders a message <div> containing an info box, success message, warning
  # message, or error message.
  #
  # @param type [:error, :warning, :success, :info] the type of message to
  #   provide. Used to determine the style of the message.
  # @param text [String] the message text
  # @return [ActiveSupport::SafeBuffer] a message <div>
  def render_message(type, text)
    render partial: "layouts/message", locals: {type: type, text: text}
  end
  
  # Renders all messages (contained in \@messages) and flash messages for a
  # view, grouped by type.
  # 
  # @return [ActiveSupport::SafeBuffer] a number of message <div>s
  # @see #render_message
  def render_messages
    order = [:error, :warning, :success, :info]
    @messages ||= []
    @messages.concat(flash.map{|k,v| {type: k.to_sym, text: v}}) if flash
    safe_join(@messages.sort_by{|m| order.index(m[:type]) || order.length}.map{|m| render_message(m[:type], m[:text]) })
  end
  
  # Takes an IATA airline code which may or may not contain a
  # disambiguation string, and returns only the IATA code.
  # 
  # Since IATA airline codes are limited and thus may not be unique, non-unique
  # codes will contain a hyphen followed by an airline name when used as a
  # parameter. This method removes everything except the IATA code from the
  # string.
  # 
  # @param iata_airline_code [String] an IATA airline code and possibly an airline name
  # @return [String] an IATA airline code
  # @see Airline#plain_code
  def iata_airline_code_display(iata_airline_code)
    iata_airline_code.split("-").first
  end
  
  # Renders an image containing an icon for an airline's logo.
  # 
  # @param icao_code [String] the ICAO code for the airline whose logo is to be
  #   displayed
  # @param title [String] an optional title attribute for the logo image. If
  #   not provided, the airline's ICAO code will be used.
  # @param css_class [Array<String>] an optional set of CSS classes to apply to
  #   the logo image.
  # @return [ActiveSupport::SafeBuffer] an image_tag for an airline logo
  def airline_icon(icao_code, title: nil, css_class: nil)
    return image_tag("assets/blank.png", class: "airline-icon") unless icao_code
    icao_code = icao_code.upcase
    title ||= icao_code
    class_array = ["airline-icon"]
    class_array |= css_class if css_class
    return image_tag("#{ExternalImage::ROOT_PATH}/flights/airline-icons/icao/#{icao_code}.png", title: title, alt: icao_code, class: class_array, onerror: "this.src='assets/blank.png';this.onerror='';")
  end
  
  # Renders an image containing a country flag.
  # 
  # @param country [String] the country whose flag is to be displayed
  # @param title [String] an optional title attribute for the flag image. If
  #   not provided, the country's name will be used.
  # @return [ActiveSupport::SafeBuffer] an image_tag for a country flag
  def country_flag_icon(country, title: nil)
    return image_tag("/assets/blank.png", class: "country-flag-icon") unless country
    title ||= country
    return image_tag("#{ExternalImage::ROOT_PATH}/flights/country-flags/#{country.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9_-]/, "").squeeze("-")}.png", title: title, class: "country-flag-icon", onerror: "this.src='assets/blank.png';this.onerror='';")
  end
  
  # Provides monospace formatting for a string. Generally used for formatting IATA and ICAO codes.
  #
  # @param code [ActiveSupport::SafeBuffer, String] the text to format
  # @return [ActiveSupport::SafeBuffer] HTML text formatted with a monospace font
  def code_mono(code)
    return nil unless code.present?
    return content_tag(:span, code, class: %w(code-mono))
  end
  
  # Renders a link which the user can click on to sort a table column. Used in
  # table headers. Includes an arrow showing the direction of the sort if the
  # table is already sorted by this column.
  #
  # In order for sort_link to work, {Table.sort_parse} must
  # have been called from the controller and stored in +@sort+.
  #
  # @param link_text [String] the text to use for the link
  # @param link_sort_category [Symbol] a symbol representing the name of the
  #   sortable column this link sorts. Compared to +@sort+ to determine if
  #   the table is already sorted by this column.
  # @param default_direction [:asc, :desc] The direction to sort this column,
  #   if a direction is not provided in the page URL parameters.
  # @param page_anchor [String] The ID of the table to sort, so that the table
  #   remains in view when a sort link is clicked.
  # @return [ActiveSupport::SafeBuffer] a link_to tag for sorting a table
  #   column.
  # @see Table.sort_parse
  def sort_link(link_text, link_sort_category, default_direction, page_anchor=nil)
    param_category, param_direction = @sort

    if param_category == link_sort_category
      if param_direction == :asc
        category_sort_direction_indicator = content_tag(:span, sanitize("&#x25B2;"), class: "sort-direction") # Up Triangle
      elsif param_direction == :desc
        category_sort_direction_indicator = content_tag(:span, sanitize("&#x25BC;"), class: "sort-direction") # Down Triangle
      end
    else
      category_sort_direction_indicator = nil
    end
    
    case default_direction
    when :asc
      sort_dir_string = ["desc","asc"]
      sort_direction = ["-",""]
    else
      sort_dir_string = ["asc","desc"]
      sort_direction = ["","-"]
    end
    if (param_category == link_sort_category && param_direction == default_direction)
      sort_polarity = sort_direction[0]
    else
      sort_polarity = sort_direction[1]
    end
    link_to(safe_join([link_text, category_sort_direction_indicator].compact, " "), url_for(region: params[:region], sort: sort_polarity.to_s + link_sort_category.to_s, anchor: page_anchor), class: "sort")
  end

  # Takes a tail number and renders an image_tag for the country flag of the
  # matching country.
  # 
  # @param tail_number [String] an aircraft tail number
  # @return [ActiveSupport::SafeBuffer] an image_tag for a country flag
  # @see TailNumber.country
  def tail_number_country_flag(tail_number)
    country_flag_icon(TailNumber.country(tail_number))
  end
  
  # Takes a tail number and prepends an image_tag for the appropriate country
  # flag to it.
  # 
  # @param tail_number [String] an aircraft tail number
  # @param show_blank_flag [Boolean] whether or not to show a blank placeholder
  #   flag image if the country cannot be determined
  # @return [ActiveSupport::SafeBuffer] an image_tag for a country flag, and
  #   the provided tail number
  # @see TailNumber.country
  # @see TailNumber.country_format
  def tail_number_with_country_flag(tail_number, show_blank_flag=true)
    country_format = TailNumber.country_format(tail_number)
    tail_link = link_to(country_format[:tail], show_tail_path(tail_number), title: "View flights on tail number #{country_format[:tail]}")
    if country_format[:country] || show_blank_flag
      return country_flag_icon(country_format[:country]) + " " + tail_link
    else
      return tail_link
    end
  end
  
  
  # GREAT CIRCLE MAPPER HELPER FUNCTIONS
  
  # Creates HTML for a map with region select tabs.
  # 
  # @param map [Map] the map to show
  # @param selected_region [Array] the currently active region as an array of
  #   ICAO prefixes (e.g. ["K","PH"])
  # @option [String] :anchor (nil) a page anchor position for the region select links to link to
  # @return [ActiveSupport::SafeBuffer] HTML for a map with region select tabs
  # @see Map#gcmap_regions
  def gcmap_with_region_select(map, selected_region, anchor: nil)
    return content_tag(:div, id: anchor) do
      if map && map.gcmap_exists?
        concat gcmap_region_select_links(map, selected_region, anchor: anchor)
        concat map.gcmap
      else
        if selected_region.length > 0
          concat render_message(:warning, "Paul has taken no flights in #{"region".pluralize(selected_region.count)} #{selected_region.join(", ")}.")
        else
          concat render_message(:warning, "When flights have been added, you’ll see a map here.")
        end
      end
    end
  end
    
  # Creates region select tabs.
  # 
  # @param map [Map] the map to show
  # @param selected_region [Array] the currently active region as an array of
  #   ICAO prefixes (e.g. ["K","PH"])
  # @option [String] :anchor (nil) a page anchor position for the region select links to link to
  # @return [ActiveSupport::SafeBuffer] HTML region select tabs
  # @see Map#gcmap_regions
  def gcmap_region_select_links(map, selected_region, anchor: nil)
    region_hash = map.gcmap_regions(selected_region)
    tabs = Array.new
    
    region_hash.each do |region, values|
      if values[:selected]
        tabs.push(content_tag(:li, region, class: "selected"))
      else
        tabs.push(content_tag(:li, link_to(region, url_for(params.permit(:id, :sort).merge(region: values[:icao].join("-"), anchor: anchor)))))
      end
    end
    
    if tabs.length > 1
      return content_tag(:div, content_tag(:ul, safe_join(tabs), class: "region-select"), class: "region-select")
    else
      return ""
    end
    
    
  end
  
end
