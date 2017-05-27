module Duration

  # Need to do scanning and validation with different regexes
  # Wasn't able to figure out proper pattern that would both validate and capture things properly
  # The anchored pattern only returns the last matching group but validates things properly :/
  SCAN_PATTERN = /(\d+(?:\.\d+)?)([hms])/
  VALIDATION_PATTERN = /\A(?:(\d+(?:\.\d+)?)([hms]))*\z/
  
  # Map supported units into secs
  UNITS_IN_S = {
    'h' => 60 * 60,
    'm' => 60,
    's' => 1
  }

  # Calculates duration strings into seconds.
  # Supports format:
  # xhymzs
  # The value given before unit can be also a floating point number
  #
  # @param [String] duration string
  # @return [Float] seconds
  def parse_duration(duration)
    raise ArgumentError, "Given duration does not match expected pattern" unless duration =~VALIDATION_PATTERN
    elements = duration.scan(SCAN_PATTERN)
    elements.map{ |n, unit|
      if UNITS_IN_S[unit]
        n.to_f * UNITS_IN_S[unit]
      else
        raise ArgumentError, "Unknown unit: #{unit}"
      end
    }.reduce(:+).to_f
  end

end
