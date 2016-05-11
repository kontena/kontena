require_relative 'services_helper'

module Kontena::Cli::Services
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option ["-l", "--lines"], "LINES", "How many lines to show", default: '100'
    option "--since", "SINCE", "Show logs since given timestamp"
    option ["-i", "--instance"], "INSTANCE", "Show only given instance specific logs"

    def execute
      require_api_url
      token = require_token
      last_id = nil
      loop do
        query_params = []
        query_params << "limit=#{lines}"
        query_params << "from=#{last_id}" unless last_id.nil?
        query_params << "since=#{since}" if !since.nil? && last_id.nil?
        query_params << "container=#{name}-#{instance}" if instance

        result = client(token).get("services/#{current_grid}/#{name}/container_logs?#{query_params.join('&')}")
        result['logs'].each do |log|
          color = color_for_container(log['name'])
          instance_number = log['name'].match(/^.+-(\d+)$/)[1]
          name = instance_number.nil? ? log['name'] : instance_number
          prefix = "#{log['created_at']} [#{name}]:".colorize(color)
          puts "#{prefix} #{log['data']}"
          last_id = log['id']
        end
        break unless tail?
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
