class StackRemoveWorker
  include Celluloid
  include Logging

  def perform(stack_id)
    stack = Stack.find_by(id: stack_id)
    if stack
      stop_stack(stack)
      remove_stack(stack)
    end
  end

  def stop_stack(stack)
    stack.grid_services.each do |service|
      GridServices::Stop.run(grid_service: service)
    end
  end

  def remove_stack(stack)
    stack.grid_services.order_by(created_at: 1).each do |service|
      outcome = GridServices::Delete.run(grid_service: service)
      if outcome.success?
        begin
          Timeout::timeout(600) do
            sleep 1 until GridService.find_by(id: service.id).nil?
          end
        rescue Timeout::Error
          error "Removing of #{service.to_path} timed out"
        end
      else
        error "Cannot remove service #{service.to_path}: #{outcome.errors.message}"
      end
    end
    if stack.grid_services.count == 0
      stack.destroy
    end
  end
end
