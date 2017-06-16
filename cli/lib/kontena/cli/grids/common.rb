module Kontena::Cli::Grids
  module Common

    ##
    # @param [Hash] grid
    def print_grid(grid)
      host = ENV['KONTENA_URL'] || self.current_master['url']
      puts "#{grid['name']}:"
      puts "  uri: #{host.sub('http', 'ws')}"
      puts "  initial_size: #{grid['initial_size']}"
      puts "  default_affinity: "
      grid['default_affinity'].to_a.each do |a|
        puts "    - #{a}"
      end
      puts "  subnet: #{grid['subnet']}"
      puts "  supernet: #{grid['supernet']}"
      root_dir = grid['engine_root_dir']
      nodes = client(require_token).get("grids/#{grid['name']}/nodes")
      nodes = nodes['nodes'].select{|n| n['connected'] == true }
      node_count = nodes.size
      puts "  stats:"
      puts "    nodes: #{nodes.size} of #{grid['node_count']}"

      cpu_total = nodes.map{|n| n['cpus'].to_i}.inject(:+)
      puts "    cpus: #{cpu_total || 0}"

      loads = calculate_loads(nodes, node_count)
      puts "    load: #{(loads[:'1m'] || 0.0).round(2)} #{(loads[:'5m'] || 0.0).round(2)} #{(loads[:'15m'] || 0.0).round(2)}"

      mem_total = nodes.map{|n| n['mem_total'].to_i}.inject(:+)
      mem_used = calculate_mem_used(nodes)
      puts "    memory: #{to_gigabytes(mem_used)} of #{to_gigabytes(mem_total)} GB"

      total_fs = calculate_filesystem_stats(nodes)
      puts "    filesystem: #{to_gigabytes(total_fs['used'])} of #{to_gigabytes(total_fs['total'])} GB"

      puts "    users: #{grid['user_count']}"
      puts "    services: #{grid['service_count']}"
      puts "    containers: #{grid['container_count']}"
      if statsd = grid.dig('stats', 'statsd')
        puts "  exports:"
        puts "    statsd: #{statsd['server']}:#{statsd['port']}"
      end
      if logs = grid.dig('logs')
        puts "logs:"
        puts "  forwarder: #{logs['forwarder']}"
        logs['opts'].each do |k,v|
          puts "  #{k}: #{v}"
        end
      end
    end

    def grids
      @grids ||= client.get('grids')
    end

    # @param [Array<Hash>] nodes
    # @param [Fixnum] node_count
    # @return [Hash]
    def calculate_loads(nodes, node_count)
      loads = {:'1m' => 0.0, :'5m' => 0.0, :'15m' => 0.0}
      return loads if node_count == 0

      loads[:'1m'] = nodes.map{|n| n.dig('resource_usage', 'load', '1m').to_f }.inject(:+) / node_count
      loads[:'5m'] = nodes.map{|n| n.dig('resource_usage', 'load', '5m').to_f }.inject(:+) / node_count
      loads[:'15m'] = nodes.map{|n| n.dig('resource_usage', 'load', '15m').to_f }.inject(:+) / node_count
      loads
    end

    # @param [Array<Hash>] nodes
    # @return [Float]
    def calculate_mem_used(nodes)
      nodes.map{|n|
        mem = n.dig('resource_usage', 'memory')
        if mem
          mem['used'] - (mem['cached'] + mem['buffers'])
        else
          0.0
        end
      }.inject(:+)
    end

    # @param [Array<Hash>] nodes
    # @return [Hash]
    def calculate_filesystem_stats(nodes)
      total_fs = {
        'used' => 0.0,
        'total' => 0.0
      }
      nodes.each do |node|
        root_dir = node['engine_root_dir']
        filesystems = node.dig('resource_usage', 'filesystem') || []
        root_fs = filesystems.find{|fs| fs['name'] == root_dir}
        total_fs['used'] += root_fs['used']
        total_fs['total'] += root_fs['total']
      end

      total_fs
    end

    def find_grid_by_name(name)
      grids['grids'].find {|grid| grid['name'] == name }
    end

    def to_gigabytes(amount)
      return 0.0 if amount.nil?
      (amount.to_f / 1024 / 1024 / 1024).to_f.round(2)
    end

    # @return [Hash] /v1/grids/:grid JSON { ... }
    def get_grid(name = nil)
      if name
        client(require_token).get("grids/#{name}")
      elsif current_grid
        client(require_token).get("grids/#{current_grid}")
      else
        exit_with_error "No grid given or selected"
      end
    end

    module Parameters
      def self.included(base)
        base.option "--default-affinity", "[AFFINITY]", "Default affinity rule for the grid", multivalued: true
        base.option "--statsd-server", "STATSD_SERVER", "Statsd server address (host:port)"
        base.option "--log-forwarder", "LOG_FORWARDER", "Set grid wide log forwarder (set to 'none' to disable)"
        base.option "--log-opt", "[LOG_OPT]", "Set log options (key=value)", multivalued: true
      end

      def validate_log_opts
        if !log_opt_list.empty? && log_forwarder.nil?
          raise Kontena::Errors::StandardError.new(1, "Need to specify --log-forwarder when using --log-opt")
        end
      end

      def parse_log_opts
        opts = {}
        log_opt_list.each do |opt|
          key, value = opt.split('=')
          opts[key.to_sym] = value
        end
        opts
      end

      def validate_grid_parameters
        validate_log_opts
      end

      def build_grid_parameters(payload)
        if statsd_server
          server, port = statsd_server.split(':')
          payload[:stats] = {
            statsd: {
              server: server,
              port: port || 8125
            }
          }
        end

        if log_forwarder
          payload[:logs] = {
            forwarder: log_forwarder,
            opts: parse_log_opts
          }
        end

        unless default_affinity_list.empty?
          payload[:default_affinity] = default_affinity_list
        end
      end
    end
  end
end
