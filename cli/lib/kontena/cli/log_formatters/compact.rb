require 'logger'

module Kontena
  module Cli
    module LogFormatter
      class Compact < Logger::Formatter
        def self.ms_since_first
          Time.now.to_f - @first_log
        end

        def self.ms_since_last
          ((Time.now.to_f - @last_log) * 1000).to_i
        ensure
          @last_log = Time.now.to_f
        end

        def self.__init_timers__
          @first_log = $KONTENA_START_TIME || Time.now.to_f
          @last_log = @first_log
        end

        __init_timers__

        DEBUG_INDICATOR = Kontena.pastel.inverse.bright_blue('DEBUG').freeze
        WARN_INDICATOR  = Kontena.pastel.inverse.yellow('WARN ').freeze
        INFO_INDICATOR  = Kontena.pastel.inverse.cyan('INFO ').freeze
        ERROR_INDICATOR = Kontena.pastel.inverse.red('ERROR').freeze

        def colorize_severity(severity)
          case severity[0..0]
          when 'D' then DEBUG_INDICATOR
          when 'W' then WARN_INDICATOR
          when 'I' then INFO_INDICATOR
          when 'E', 'F' then ERROR_INDICATOR
          else severity[0..0]
          end
        end

        TS_FORMAT = '%4d'.freeze

        def colorized_time
          elapsed = self.class.ms_since_last
          ts = TS_FORMAT % [elapsed]
          if elapsed > 300
            Kontena.pastel.red(ts)
          elsif elapsed > 100
            Kontena.pastel.yellow(ts)
          else
            ts
          end
        end

        if ENV['DEBUG_PERF']
          define_method :call do |severity, time, progname, msg|
            "#{colorize_severity(severity)} #{colorized_time} #{msg2str(msg)}\n"
          end
        else
          define_method :call do |severity, time, progname, msg|
            "#{colorize_severity(severity)} #{msg2str(msg)}\n"
          end
        end
      end
    end
  end
end
