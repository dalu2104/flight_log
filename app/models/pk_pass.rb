###############################################################################
# Defines a boarding pass using Apple's PassKit Package (PKPass) format.      #
###############################################################################

class PKPass < ApplicationRecord
  after_initialize :set_values
  before_create :check_for_existing_flight
  
  validates :serial_number, :presence => true, :uniqueness => true
  validates :pass_json, :presence => true
  
  # Returns the pass's barcode string
  def barcode
    if @pass.dig('barcodes')
      return @pass.dig('barcodes', 0, 'message')
    else
      return @pass.dig('barcode', 'message')
    end
  end
  
  # Returns a BoardingPass based on the PKPass's barcode field
  def bcbp
    return BoardingPass.new(barcode)
  end
  
  # Returns a hash of form default values for this pass
  def form_values
    output = Hash.new
    data = BoardingPass.new(barcode, interpretations: false).data
    output.store(:serial_number, serial_number)
    output.store(:origin_airport_iata, data.dig(:repeated, 0, :mandatory, 26, :raw))
    output.store(:destination_airport_iata, data.dig(:repeated, 0, :mandatory, 38, :raw))
    rel_date = @pass.dig("relevantDate")
    if rel_date.present?
      begin
        output.store(:departure_date_local, Date.parse(rel_date))
        output.store(:departure_utc, Time.parse(rel_date).utc)
      rescue ArgumentError
      end
    end
    airline = data.dig(:repeated, 0, :mandatory, 42, :raw)&.strip
    if airline.present?
      output.store(:airline_iata, airline)
      bp_issuer = data.dig(:unique, :conditional, 21, :raw)&.strip
      marketing_carrier = data.dig(:repeated, 0, :conditional, 19, :raw)&.strip
      if (bp_issuer.present? && airline != bp_issuer)
        output.store(:codeshare_airline_iata, bp_issuer)
      elsif (marketing_carrier.present? && airline != marketing_carrier)
        output.store(:codeshare_airline_iata, marketing_carrier)
      end
      begin
        airline_compartments = JSON.parse(File.read('app/assets/json/airline_compartments.json'))
        compartment_code = data.dig(:repeated, 0, :mandatory, 71, :raw)
        if compartment_code.present?
          travel_class = airline_compartments.dig(airline, compartment_code, "name")
          output.store(:travel_class, Flight.get_class_id(travel_class))
        end
      rescue Errno::ENOENT
      end
    end
    output.store(:flight_number, data.dig(:repeated, 0, :mandatory, 43, :raw)&.strip)
    output.store(:boarding_pass, barcode)
    return output
  end
  
  # Returns an array of hashes of summary details for all boarding passes
  # that are not yet associated with a flight.
  def self.pass_summary_list
    PKPass.where(flight_id: nil).map{|pass|
      fields = BoardingPass.new(pass.barcode, interpretations: false).summary_fields
      fields.store(:date, Time.parse(JSON.parse(pass.pass_json)["relevantDate"]))
      fields.store(:id, pass.id)
      fields
    }.sort_by{|h| h[:date]}
  end
  
  # Returns a hash of Flights with updated boarding passes, with flight ids as the keys and pass ids as the values
  def self.flights_with_updated_passes
    return PKPass.where.not(flight_id: nil).map{|pass| {pass.flight_id => pass.id}}.reduce({}, :merge)
  end
  
  protected
  
    def set_values
      @pass = JSON.parse(self.pass_json)
      self.assign_attributes({:serial_number => [@pass.dig('passTypeIdentifier'),@pass.dig('serialNumber')].join(",")})
    end
    
    def check_for_existing_flight
      associated_flight = Flight.where(pass_serial_number: self.serial_number)
      if associated_flight.any?
        self.assign_attributes({flight_id: associated_flight.first.id})
      end
    end

end