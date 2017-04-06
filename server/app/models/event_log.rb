class EventLog
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  DEBUG = 0
  INFO = 1
  WARN = 2
  ERROR = 3

  field :severity, type: Integer
  field :type, type: String
  field :msg, type: String
  field :meta, type: Hash

  belongs_to :grid
  belongs_to :stack
  belongs_to :grid_service
  belongs_to :volume
  belongs_to :host_node

  index({ created_at: 1 })
  index({ severity: 1 })
  index({ reason: 1 })
  index({ grid_id: 1 })
  index({ stack_id: 1 })
  index({ grid_service_id: 1 })
  index({ volume_id: 1 })
  index({ host_node_id: 1 })

  def relationships
    relations = []
    if self.grid_id && grid = self.grid
      relations << { id: grid.to_path, type: 'grid' }
    end
    if self.stack_id && stack = self.stack
      relations << { id: stack.to_path, type: 'stack' }
    end
    if self.grid_service_id && service = self.grid_service
      relations << { id: service.to_path, type: 'service' }
    end
    if self.volume_id && volume = self.volume
      relations << { id: volume.to_path, type: 'volume' }
    end
    if self.host_node_id && node = self.host_node
      relations << { id: node.to_path, type: 'node' }
    end

    relations
  end
end
