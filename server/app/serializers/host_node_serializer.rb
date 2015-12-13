require 'json_serializer'

class HostNodeSerializer < JsonSerializer
  attribute :id
  attribute :connected
  attribute :created_at
  attribute :updated_at
  attribute :last_seen_at
  attribute :name
  attribute :os
  attribute :driver
  attribute :kernel_version
  attribute :labels
  attribute :mem_total
  attribute :mem_limit
  attribute :cpus
  attribute :public_ip
  attribute :private_ip
  attribute :node_number
  attribute :peer_ips
  attribute :grid, :GridSerializer

  def peer_ips
    object.grid.host_nodes.ne(id: object.id).map{|node| node.private_ip}.compact
  end

  def id
    object.node_id
  end

  def to_hash
    super
  end

  def serializable_object
    return nil unless @object

    if @object.kind_of?(Enumerable)
      @object.to_a.map { |item| self.class.new(item).to_hash }
    else
      to_hash
    end
  end


end