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

        def colorize_severity(severity)
          case severity[0..0]
          when 'D' then Kontena.pastel.blue('D')
          when 'W' then Kontena.pastel.yellow('W')
          when 'I' then Kontena.pastel.cyan('I')
          when 'E', 'F' then Kontena.pastel.red('E')
          else severity[0..0]
          end
        end

        def colorize_time
          elapsed = self.class.ms_since_last
          str = sprintf("%6s", "#{elapsed}ms")
          if elapsed > 300
            Kontena.pastel.red(str)
          elsif elapsed > 100
            Kontena.pastel.yellow(str)
          else
            str
          end
        end

        LEFT_BRACKET = Kontena.pastel.cyan('[').freeze
        RIGHT_BRACKET = Kontena.pastel.cyan(']').freeze

        def call(severity, time, progname, msg)
          "#{LEFT_BRACKET}#{colorize_severity(severity)} #{colorize_time} #{progname}#{RIGHT_BRACKET} #{msg2str(msg)}\n"
        end
      end
    end
  end
end
