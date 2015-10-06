module Kontena
  module Machine
    module Azure
      class Logger
        def info(msg)

        end

        def error_with_exit(msg)
          puts msg.colorize(:red)
        end

        def warn(msg)
          puts msg.colorize(:yellow)
        end

        def error(msg)
          puts msg.colorize(:red)
        end

        def exception_message(msg)
          puts msg.colorize(:red)
        end
      end
    end
  end
end