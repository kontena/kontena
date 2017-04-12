module Kontena::Actors
  class ContainerCoroner
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    INVESTIGATION_PERIOD = 20

    # @param [String] node_id
    def initialize(node_id)
      @node_id = node_id
      @processing = false
    end

    def process
      prev = nil
      while @processing do
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
      rpc_request('/containers/cleanup', [@node_id, data])
    rescue => exc
      warn "failed to send report: #{exc.message}"
      retry
    end

    # @return [Array<Docker::Container>]
    def all_containers
      Docker::Container.all(all: true)
    end

    def start
      return if @processing

      @processing = true
      async.process
    end

    def stop
      return unless @processing

      @processing = false
    end

    def processing?
      @processing == true
    end
  end
end
