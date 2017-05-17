module Kontena
  module Cli
    SpinAbort = Class.new(StandardError)

    class SpinnerStatus
      attr_reader :thread, :result

      def initialize(thread)
        @thread = thread
        @result = :done
      end

      def set_title(message)
        if $stdout.tty?
          thread['update_msg'] = message
        else
          Kernel.puts "- #{message}"
        end
      end

      def warn?
        @result == :warn
      end

      def failed?
        @result == :fail
      end

      def fail
        @result = :fail
      end

      def fail!
        @result = :fail
        thread['abort'] = true
        raise SpinAbort
      end

      def warn
        @result = :warn
      end
    end

    class Spinner
      CHARS = ['\\', '|', '/', '-']
      CHARS_LENGTH = CHARS.length

      def self.spin_no_tty(msg, &block)
        unless block_given?
          Kernel.puts "\r [" + "done".colorize(:green) + "] #{msg}"
          return
        end

        Kernel.puts "* #{msg}.. "
        result = nil
        status = nil
        begin
          spin_status = SpinnerStatus.new(Thread.current)
          result = yield spin_status
          Kernel.puts "* #{msg}.. #{spin_status.result}"
        rescue SpinAbort
          Kernel.puts "* #{msg}.. fail"
        rescue SystemExit => ex
          status = ex.status
          if status == 0
            Kernel.puts "* #{msg}.. done"
          else
            Kernel.puts "* #{msg}.. fail"
          end
        rescue Exception => ex
          Kernel.puts "* #{msg}.. fail"
          ENV["DEBUG"] && $stderr.puts("#{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}")
          raise ex
        end
        exit(status) if status
        result
      end

      def self.spin(msg, &block)
        return spin_no_tty(msg, &block) unless $stdout.tty?

        unless block_given?
          Kernel.puts "\r [" + "done".colorize(:green) + "] #{msg}"
          return
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
              until !Thread.current['pause'] || Thread.current['abort']
                sleep 0.1
              end
              Kernel.print "\r#{message}#{CHARS[curr_index]}"
            end

            if Thread.current['update_msg']
              msg = Thread.current['update_msg']
              Thread.current['update_msg'] = nil
              Thread.current['msg'] = msg
              message = "    *   #{msg} .. "
              Kernel.print "\r#{message}#{CHARS[curr_index]}"
            end

            break if Thread.current['abort']

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

        Thread.main['spinners'] << spin_thread

        status = nil
        result = nil
        begin
          spin_status = SpinnerStatus.new(spin_thread)
          result = yield spin_status
          spin_thread.kill
          case spin_status.result
          when :warn
            Kernel.puts "\r [" + "warn".colorize(:yellow) + "] #{msg}     "
          when :fail
            Kernel.puts "\r [" + "fail".colorize(:red) + "] #{msg}     "
          else
            Kernel.puts "\r [" + "done".colorize(:green) + "] #{msg}     "
          end
        rescue SystemExit => ex
          spin_thread.kill
          if ex.status == 0
            Kernel.puts "\r [" + "done".colorize(:green)   + "] #{msg}     "
          else
            Kernel.puts "\r [" + "fail".colorize(:red)   + "] #{msg}     "
          end
          status = ex.status
        rescue SpinAbort
          spin_thread.kill
          Kernel.puts "\r [" + "fail".colorize(:red)   + "] #{msg}     "
          if ENV["DEBUG"]
            $stderr.puts "Spin aborted through fail!"
          end
        rescue Exception => ex
          spin_thread.kill
          Kernel.puts "\r [" + "fail".colorize(:red)   + "] #{msg}     "
          ENV["DEBUG"] && $stderr.puts("#{ex.class.name} : #{ex.message}\n#{ex.backtrace.join("\n  ")}")
          raise ex
        ensure
          unless Thread.main['spinner_msgs'].empty?
            while msg = Thread.main['spinner_msgs'].shift
              Kernel.puts msg
            end
          end
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
