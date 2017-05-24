module Kontena::Cli::Containers
  class ListCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option ['--all', '-a'], :flag, 'Show all containers'

    def execute
      require_api_url
      token = require_token

      params = '?'
      params << 'all=1' if all?
      result = client(token).get("containers/#{current_grid}#{params}")
      containers = result['containers']
      id_column = longest_string_in_array(containers.map {|c| "#{c['node']['name']}/#{c['name']}"})
      image_column = longest_string_in_array(containers.map {|c| c['image'] })
      columns = "%-#{id_column + 2}s %-#{image_column + 2}s %-30s %-20s %-10s"
      puts columns % [ 'CONTAINER ID', 'IMAGE', 'COMMAND', 'CREATED', 'STATUS']
      result['containers'].reverse.each do |container|
        puts columns % [
          "#{container['node']['name']}/#{container['name']}",
          container['image'],
          "\"#{container['cmd'].to_a.join(' ')[0..26]}\"",
          "#{time_ago(container['created_at'])} ago",
          container_status(container)
        ]
      end
    end

    def longest_string_in_array(array)
      longest = 0
      array.each do |item|
        longest = item.length if item.length > longest
      end

      longest
    end

    def container_status(container)
      s = container['state']
      if s['paused']
        'paused'.freeze
      elsif s['restarting']
        'restarting'.freeze
      elsif s['oom_killed']
        'oom_killed'.freeze
      elsif s['dead']
        'dead'.freeze
      elsif s['running']
        'running'.freeze
      else
        'stopped'.freeze
      end
    end
  end
end
