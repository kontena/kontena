module Kontena::Cli::Helpers
  module TimeHelper
    # Return an approximation of how long ago the given time was.
    # @param time [String]
    # @param terse [Boolean] very terse output (2-3 chars wide)
    def time_since(time, terse: false)
      return '' if time.nil? || time.empty?

      dt = Time.now - Time.parse(time)

      dt_s = dt.to_i
      dt_m, dt_s = dt_s / 60, dt_s % 60
      dt_h, dt_m = dt_m / 60, dt_m % 60
      dt_d, dt_h = dt_h / 60, dt_h % 60

      parts = []
      parts << "%dd" % dt_d if dt_d > 0
      parts << "%dh" % dt_h if dt_h > 0
      parts << "%dm" % dt_m if dt_m > 0
      parts << "%ds" % dt_s

      if terse
        return parts.first
      else
        return parts.join('')
      end
    end
  end
end
