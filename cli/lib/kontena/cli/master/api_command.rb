module Kontena::Cli::Master
  class ApiCommand < Kontena::Command

    include Kontena::Cli::Common

    requires_current_master_token

    parameter "HTTP_METHOD", "HTTP Method (GET, POST, PUT, DELETE, PATCH, GET_STREAM)" do |http_method|
      http_method.downcase.to_sym
    end

    parameter "REQUEST_PATH", "Path on server", default: '/'

    option ['-H', '--headers'], :flag, "Show request / response headers"

    def execute
      if requires_input?(self.http_method)
        if STDIN.tty?
          exit_with_error "Data required for #{self.http_method} requests. Use piping or redirection."
        end
        data = STDIN.read
      end

      if self.http_method == :get_stream
        begin
          client.send(:get_stream, request_path, lambda {|body,_,_| puts body})
        rescue Interrupt
        end
      else
        begin
          client.send(http_method, request_path, data)
        rescue StandardError => ex
          if ex.respond_to?(:response)
            response = ex.response
          end
        end
      end

      if self.headers?
        puts pastel.green("Request headers:")
        client.last_request[:headers].each do |name, val|
          puts " * #{pastel.yellow(name)}: #{pastel.blue(val)}"
        end
        puts
        puts pastel.green("Response headers:")
        (response || client.last_response).headers.each do |name, val|
          puts " * #{pastel.yellow(name)}: #{pastel.blue(val)}"
        end
        puts
      end
      puts (response || client.last_response).body unless self.http_method == :get_steam
    end

    def requires_input?(http_method)
      case http_method
      when :post, :put, :patch then true
      else false
      end
    end
  end
end
