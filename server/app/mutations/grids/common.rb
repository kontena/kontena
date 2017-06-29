module Grids
  module Common
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def common_validations
        # common inputs for both create + update
        optional do
          array :default_affinity do
            string
          end
          array :trusted_subnets do
            string
          end
          hash :stats do
            optional do
              hash :statsd do
                required do
                  string :server
                  integer :port
                end
              end
            end
          end
          hash :logs do
            required do
              string :forwarder, in: ['fluentd', 'none'] # Only fluentd now supported, none removes log shipping
            end
            optional do
              model :opts, class: Hash
            end
          end
        end
      end
    end

    def validate_common
      if self.trusted_subnets
        self.trusted_subnets.each do |subnet|
          begin
            IPAddr.new(subnet)
          rescue IPAddr::InvalidAddressError
            add_error(:trusted_subnets, :invalid, "Invalid trusted_subnet #{subnet}")
          end
        end
      end
      if self.logs
        case self.logs[:forwarder]
        when 'fluentd'
          validate_logs_fluentd_opts(self.logs[:opts])
        end
      end
    end

    def validate_logs_fluentd_opts(opts)
      address = opts['fluentd-address']
      add_error(:logs, :forwarder, 'fluentd-address option must be given') unless address
    end

    # @param grid [Grid] set attributes on Grid
    def execute_common(grid)
      grid.stats = self.stats if self.stats
      grid.trusted_subnets = self.trusted_subnets if self.trusted_subnets
      grid.default_affinity = self.default_affinity if self.default_affinity

      if self.logs
        if self.logs[:forwarder] == 'none'
          grid.grid_logs_opts = nil
        else
          grid.grid_logs_opts = GridLogsOpts.new(forwarder: self.logs[:forwarder], opts: self.logs[:opts])
        end
      end
    end
  end
end
