module Docker
  class OverlayCidrAllocator

    class AllocationError < StandardError; end

    attr_reader :grid

    # @param [Grid] grid
    def initialize(grid)
      @grid = grid
    end

    # @param [String] service_instance_name
    # @return [OverlayCidr]
    def allocate_for_service_instance(service_instance_name)
      overlay_cidr = nil
      tries = 0
      while overlay_cidr.nil? do
        begin
          overlay_cidr = grid.overlay_cidrs.where(reserved_at: nil, container_id: nil).find_and_modify({:$set => {reserved_at: Time.now.utc}}, new: true)
          raise AllocationError.new('Cannot allocate ip') if overlay_cidr.nil?
        rescue Moped::Errors::OperationFailure
          tries += 1
          if tries > 100
            raise AllocationError.new('Cannot allocate ip')
          end
        end
      end
      overlay_cidr
    end

    def initialize_grid_subnet
      skip_first = '.0'
      skip_last = '.255'
      grid.all_overlay_ips.each do |ip|
        next if ip[-2..-1] == skip_first || ip[-4..-1] == skip_last
        begin
          OverlayCidr.with(safe: false).create(
              grid: grid,
              ip: ip,
              subnet: grid.overlay_network_size,
              reserved_at: nil
          )
        rescue Moped::Errors::OperationFailure
        end
      end
    end
  end
end