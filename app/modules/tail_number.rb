module TailNumber
  
  def self.countries
    formats = Hash.new
    formats[/^N[1-9]((\d{0,4})|(\d{0,3}[A-HJ-NP-Z])|(\d{0,2}[A-HJ-NP-Z]{2}))$/] = {
      country: "United States",
      dash: 0
    }
    formats[/^VH[A-Z]{3}$/] = {
      country: "Australia",
      dash: 2
    }
    formats[/^C[FGI][A-Z]{3}$/] = {
      country: "Canada",
      dash: 1
    }
    formats[/^B((1[5-9]\d{2})|([2-9]\d{3}))$/] = {
      country: "China",
      dash: 1
    }
    formats[/^F[A-Z]{4}$/] = {
      country: "France",
      dash: 1
    }
    formats[/^D(([A-CE-IK-O][A-Z]{3})|(\d{4}))$/] = {
      country: "Germany",
      dash: 1
    }
    formats[/^9G[A-Z]{3}$/] = {
      country: "Ghana",
      dash: 2
    }
    formats[/^SX[A-Z]{3}$/] = {
      country: "Greece",
      dash: 2
    }
    formats[/^B[HKL][A-Z]{2}$/] = {
      country: "Hong Kong",
      dash: 1
    }
    formats[/^TF(([A-Z]{3})|([1-9]\d{2}))$/] = {
      country: "Iceland",
      dash: 2
    }
    formats[/^VT[A-Z]{3}$/] = {
      country: "India",
      dash: 2
    }
    formats[/^4X[A-Z]{3}$/] = {
      country: "Israel",
      dash: 2
    }
    formats[/^JA((\d{4})|(\d{3}[A-Z])|(\d{2}[A-Z]{2})|(A\d{3}))$/] = {
      country: "Japan",
      dash: 0
    }
    formats[/^JY[A-Z]{3}$/] = {
      country: "Jordan",
      dash: 2
    }
    formats[/^9M[A-Z]{3}$/] = {
      country: "Malaysia",
      dash: 2
    }
    formats[/^PH(([A-Z]{3})|(1[A-Z]{2})|(\d[A-Z]\d)|([1-9]\d{2,3}))$/] = {
      country: "Netherlands",
      dash: 2
    }
    formats[/^ZK[A-Z]{3}$/] = {
      country: "New Zealand",
      dash: 2
    }
    formats[/^9V[A-Z]{3}$/] = {
      country: "Singapore",
      dash: 2
    }
    formats[/^B((\d(0\d{3}|1[0-4]\d{2}))|([1-9]\d{4}))$/] = {
      country: "Taiwan",
      dash: 1
    }
    formats[/^HS[A-Z]{3}$/] = {
      country: "Thailand",
      dash: 2
    }
    formats[/^UR(([A-Z]{3,4})|([1-9]\d{4}))$/] = {
      country: "Ukraine",
      dash: 2
    }
    formats[/^A6[A-Z]{3}$/] = {
      country: "United Arab Emirates",
      dash: 2
    }
    formats[/^G(([A-Z]{4})|(\d{1,2}\d{1,2}))$/] = {
      country: "United Kingdom",
      dash: 1
    }
    return formats
  end
  
  # Identifies the country associated with a given tail number.
  def self.country(tail_number)
    tail_number = tail_number.upcase.gsub("-","")
    country = countries.select{|k,v| k.match(tail_number) }.values.first
    return country.nil? ? nil : country[:country]
  end
  
  # Takes a tail number and adds dashes as appropriate.
  def self.format(tail_number)
    tail_number = tail_number.upcase.gsub("-","")
    country_format = countries.select{|k,v| k.match(tail_number) }.values.first
    return tail_number if country_format.nil? || country_format[:dash].nil? || country_format[:dash] == 0
    return "#{tail_number[0...country_format[:dash]]}-#{tail_number[country_format[:dash]..-1]}"
  end
  
  # Returns a hash of tail numbers, aircraft codes (ICAO preferred), aircraft
  # manufacturers, aircraft family/type names, airline names, airline IATA
  # codes, and flight counts
  def self.flight_count(flights)
    tail_counts = flights.reorder(nil).where.not(tail_number: nil).group(:tail_number).count
    tail_details = flights.where.not(tail_number: nil).includes(:airline, :aircraft_family)
    return nil unless tail_details.any?
    tail_details.map{|f| {f.tail_number => {
      airline_code:  f.airline.iata_airline_code,
      airline_name:  f.airline.airline_name,
      aircraft_code: f.aircraft_family&.icao_aircraft_code || f.aircraft_family&.iata_aircraft_code,
      manufacturer:  f.aircraft_family&.manufacturer,
      family_name:   f.aircraft_family&.family_name,
      departure_utc: f.departure_utc
    }}}
      .reduce{|a,b| a.merge(b){|k,oldval,newval| newval[:departure_utc] > oldval[:departure_utc] ? newval : oldval}}
      .merge(tail_counts){|k,oldval,newval| oldval.store(:count, newval); oldval}
      .map{|k,v| {
        tail_number:  k,
        count:        v[:count],
        aircraft:     v[:aircraft_code] || "",
        airline_name: v[:airline_name] || "",
        airline_code: v[:airline_code] || "",
        manufacturer: v[:manufacturer],
        family_name:  v[:family_name]
      }}
      .sort_by{|t| [-(t[:count] || 0), t[:tail_number] || ""]}
  end
  
end