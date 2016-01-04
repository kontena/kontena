require 'ipaddr'

class OverlayCidr
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ip, type: String
  field :subnet, type: String
  field :reserved_at, type: DateTime

  belongs_to :container
  belongs_to :grid

  index({ grid_id: 1 })
  index({ container_id: 1 })
  index({ grid_id: 1, ip: 1, subnet: 1 }, { unique: true })
  index({ reserved_at: 1 })

  def to_s
    "#{self.ip}/#{self.subnet}"
  end
end
