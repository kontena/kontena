module Kontena
  module Cli
    class Spinner
      
      CHARS = ['\\', '|', '/', '-']
      CHARS_LENGTH = CHARS.length

      def self.spin(msg, &block)
        unless $stdout.tty?
          Kernel.puts " [....] #{msg}"
          result = nil
          status = nil
          begin
            result = yield
          rescue SystemExit => ex
            status = ex.status
            if status == 0
              Kernel.puts " [done] #{msg}"
            else
              Kernel.puts " [fail] #{msg}"
            end
          rescue Exception => ex
            Kernel.puts " [fail] #{msg}"
            if ENV["DEBUG"]
              Kernel.puts "#{ex} #{ex.message}\n#{ex.backtrace.join("\n")}"
            end
            raise ex
          end
          exit(status) if status
          Kernel.puts " [done] #{msg}"
          return result
        end

        Thread.main['spinners'] ||= []
        unless Thread.main['spinners'].empty?
          Thread.main['spinners'].each do |thread|
            thread['pause'] = true
          end
          Kernel.puts "\r [#{'....'.colorize(:yellow)}] #{Thread.main['spinners'].last['msg']}"
        end

        Thread.main['spinner_msgs'] = []
        spin_thread = Thread.new do
          Thread.current['msg'] = msg
          message = "    *   #{msg} .. "
          Kernel.print(message + CHARS.first)
          curr_index = 0
          loop do
            if Thread.current['pause']
              sleep 0.1 until !Thread.current['pause']
              Kernel.print "\r#{message}#{CHARS[curr_index]}"
            else
              if Thread.main['spinner_msgs']
                Kernel.print "\r#{' ' * (message.gsub(/\e.+?m/, '').length + 1)}\r"
                while Thread.main['spinner_msgs'].size > 0
                  Kernel.puts "\r#{Thread.main['spinner_msgs'].shift}"
                end
                Kernel.print "\r#{message + CHARS[curr_index]}"
              end
              sleep 0.1
              Kernel.print "\b#{CHARS[curr_index]}"
              curr_index = curr_index == CHARS_LENGTH - 1 ? 0 : curr_index + 1
            end
          end
        end

        Thread.main['spinners'] << spin_thread

        status = nil
        result = nil
        begin
          result = yield
          spin_thread.kill
          Kernel.puts "\r [" + "done".colorize(:green) + "] #{msg}     "
        rescue SystemExit => ex
          spin_thread.kill
          if ex.status == 0
            Kernel.puts "\r [" + "done".colorize(:green)   + "] #{msg}     "
          else
            Kernel.puts "\r [" + "fail".colorize(:red)   + "] #{msg}     "
          end
          status = ex.status
        rescue Exception => ex
          spin_thread.kill
          Kernel.puts "\r [" + "fail".colorize(:red)   + "] #{msg}     "
          if ENV["DEBUG"]
            puts "#{ex} #{ex.message}\n#{ex.backtrace.join("\n")}"
          end
          raise ex
        end
        exit(status) if status
        Thread.main['spinners'].pop
        unless Thread.main['spinners'].empty?
          Thread.main['spinners'].last['pause'] = false
        end
        result
      end
    end

    module ShellSpinner
      def spinner(msg = "", &block)
        Kontena::Cli::Spinner.spin(msg, &block)
      end

      def puts(*msgs)
        if Thread.main['spinners'] && !Thread.main['spinners'].empty?
          msgs.each { |msg| Thread.main['spinner_msgs'] << msg }
        else
          super(*msgs)
        end
      end

      def print(*msgs)
        if Thread.main['spinners'] && !Thread.main['spinners'].empty?
          Thread.main['spinner_msgs'] << msgs.join
        else
          super(*msgs)
        end
      end
    end
  end
end
