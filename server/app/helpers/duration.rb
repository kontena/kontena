module Duration

  PATTERN = /(\d+(?:\.\d+)?)([hms])/

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
    elements = duration.scan(PATTERN)
    raise ArgumentError, "Duration pattern did not match anything" if elements.empty?
    elements.map{ |n, unit|
      n.to_f * UNITS_IN_S[unit]
    }.reduce(:+).to_f
  end

end
