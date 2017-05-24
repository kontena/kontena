require 'logger'

module Kontena
  module Cli
    module LogFormatter
      class Compact < Logger::Formatter
        def self.ms_since_first
          #((Time.now.to_f - @first_log) * 1000).to_i
          Time.now.to_f - @first_log
        end

        def self.ms_since_last
          ((Time.now.to_f - @last_log) * 1000).to_i
        ensure
          @last_log = Time.now.to_f
        end

        def self.__init_timers__
          @first_log = Time.now.to_f
          @last_log = @first_log
        end

        __init_timers__

        DEBUG_INDICATOR = Kontena.pastel.inverse.bright_blue('D').freeze
        WARN_INDICATOR  = Kontena.pastel.inverse.yellow('W').freeze
        INFO_INDICATOR  = Kontena.pastel.inverse.cyan('I').freeze
        ERROR_INDICATOR = Kontena.pastel.inverse.red('E').freeze

        def colorize_severity(severity)
          case severity[0..0]
          when 'D' then DEBUG_INDICATOR
          when 'W' then WARN_INDICATOR
          when 'I' then INFO_INDICATOR
          when 'E', 'F' then ERROR_INDICATOR
          else severity[0..0]
          end
        end

        TS_FORMAT = '%6.3fs'.freeze

        def colorize_time
          elapsed = self.class.ms_since_last
          ts = TS_FORMAT % [self.class.ms_since_first]
          if elapsed > 300
            Kontena.pastel.red.inverse(ts)
          elsif elapsed > 100
            Kontena.pastel.yellow.inverse(ts)
          else
            Kontena.pastel.inverse(ts)
          end
        end

        SEPARATOR = Kontena.pastel.inverse(' ').freeze
        HEAD_FORMAT = "%s#{SEPARATOR}%s".freeze

        def call(severity, time, progname, msg)
          (HEAD_FORMAT % [colorize_severity(severity), colorize_time]) + " #{msg2str(msg)}\n"
        end
      end
    end
  end
end
