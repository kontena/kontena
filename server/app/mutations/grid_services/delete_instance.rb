module GridServices
  class DeleteInstance < Mutations::Command
    include Workers

    required do
      model :service_instance, class: Container
    end

    def validate
      if service_instance.grid_service.deploying?
        add_error(:service, :invalid, "Cannot delete service instance because it's currently being deployed")
        return
      end
    end

    def execute
      terminator = Docker::ServiceTerminator.new(service_instance.host_node)
      terminator.terminate_service_instance(service_instance.grid_service, service_instance.instance_number, {lb: true})
    end
  end
end
