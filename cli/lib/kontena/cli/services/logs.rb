require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Services
  class Logs
    include Kontena::Cli::Common

    ##
    # @param [String] service_id
    def show(service_id, options)
      require_api_url
      token = require_token
      last_id = nil
      loop do
        query_params = []
        query_params << "from=#{last_id}" unless last_id.nil?
        query_params << "search=#{options.search}" if options.search
        query_params << "container=#{options.container}" if options.container

        result = client(token).get("services/#{current_grid}/#{service_id}/container_logs?#{query_params.join('&')}")
        result['logs'].each do |log|
          color = color_for_container(log['name'])
          puts "#{log['name'].colorize(color)} | #{log['data']}"
          last_id = log['id']
        end
        break unless options.follow
        sleep(2)
      end
    end

    def color_for_container(container_id)
      color_maps[container_id] = colors.shift unless color_maps[container_id]
      color_maps[container_id].to_sym
    end

    def color_maps
      @color_maps ||= {}
    end

    def colors
      if(@colors.nil? || @colors.size == 0)
        @colors = [:green, :yellow, :magenta, :cyan, :red,
          :light_green, :light_yellow, :ligh_magenta, :light_cyan, :light_red]
      end
      @colors
    end
  end
end
