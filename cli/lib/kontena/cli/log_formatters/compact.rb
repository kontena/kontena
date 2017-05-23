require 'logger'

module Kontena
  module Cli
    module LogFormatter
      class Compact < Logger::Formatter
        def self.ms_since_first
          ((Time.now.to_f - @first_log) * 1000).to_i
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

        DEBUG_INDICATOR = Kontena.pastel.bright_blue('D').freeze
        WARN_INDICATOR  = Kontena.pastel.yellow('W').freeze
        INFO_INDICATOR  = Kontena.pastel.cyan('I').freeze
        ERROR_INDICATOR = Kontena.pastel.red('E').freeze

        def colorize_severity(severity)
          case severity[0..0]
          when 'D' then DEBUG_INDICATOR
          when 'W' then WARN_INDICATOR
          when 'I' then INFO_INDICATOR
          when 'E', 'F' then ERROR_INDICATOR
          else severity[0..0]
          end
        end

        TS_FORMAT = '%+6dms'.freeze
        TS_ZERO   = Kontena.pastel.bright_black.on_black(sprintf('%+6sms', '<1')).freeze

        def colorize_time
          elapsed = self.class.ms_since_last
          if elapsed.zero?
            TS_ZERO
          elsif elapsed > 300
            Kontena.pastel.red.on_black(TS_FORMAT % [elapsed])
          elsif elapsed > 100
            Kontena.pastel.yellow.on_black(TS_FORMAT % [elapsed])
          else
            Kontena.pastel.on_black(TS_FORMAT % [elapsed])
          end
        end

        SEPARATOR = Kontena.pastel.on_black(' ').freeze
        HEAD_FORMAT = "%s#{SEPARATOR}%s".freeze

        def call(severity, time, progname, msg)
          (HEAD_FORMAT % [colorize_severity(severity), colorize_time]) + " #{msg2str(msg)}\n"
        end
      end
    end
  end
end
