module Kontena::Actors
  class ContainerCoroner
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    INVESTIGATION_PERIOD = 20

    # @param [Boolean] autostart
    def initialize(autostart = true)
      async.process if autostart
    end

    def process
      prev = nil
      loop do
        ids = all_containers.map { |c| c.id }
        if prev
          diff = prev - ids
          report(diff) if diff.size > 0
        end
        prev = ids
        sleep INVESTIGATION_PERIOD
      end
    rescue => exc
      warn "process loop failed: #{exc.message}"
      retry
    end

    def report(data)
      rpc_request('/containers/cleanup', [data])
    rescue => exc
      warn "failed to send report: #{exc.message}"
      sleep 1
      retry
    end

    # @return [Array<Docker::Container>]
    def all_containers
      Docker::Container.all(all: true)
    end
  end
end
