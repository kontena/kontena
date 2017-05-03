require_glob __dir__ + '/scheduler/**/*.rb'
require_glob __dir__ + '/docker/*.rb'

class GridServiceScheduler

  STRATEGIES = {
      'ha' => Scheduler::Strategy::HighAvailability,
      'daemon' => Scheduler::Strategy::Daemon,
      'random' => Scheduler::Strategy::Random
  }.freeze

  attr_reader :strategy, :filters

  # @param [#find_node] strategy
  def initialize(strategy)
    @strategy = strategy
    @filters = [
      Scheduler::Filter::VolumePlugin.new,
      Scheduler::Filter::VolumeInstance.new,
      Scheduler::Filter::Affinity.new,
      Scheduler::Filter::Port.new,
      Scheduler::Filter::Memory.new,
      Scheduler::Filter::Dependency.new
    ]
    @mutex = Mutex.new
  end

  # @param [GridService] grid_service
  # @param [Array<HostNode>] host_nodes
  # @return [Array<HostNode>]
  def selected_nodes(grid_service, host_nodes)
    available_nodes = host_nodes.map {|n| Scheduler::Node.new(n) }
    count = self.calculated_instance_count(grid_service, available_nodes)
    nodes = []
    count.times do |i|
      begin
        nodes << self.select_node(
          grid_service, i + 1, available_nodes
        )
      rescue Scheduler::Error
      end
    end

    nodes.map { |n| n.node }
  end

  # @param [GridService] grid_service
  # @param [Array<Scheduler::Node>] nodes
  # @return [Integer]
  def calculated_instance_count(grid_service, nodes)
    available_nodes = nodes.map { |n| n.clone } # we don't want to touch originals here
    max_instances = self.strategy.instance_count(nodes.size, grid_service.container_count)
    nodes = []
    max_instances.times do |i|
      begin
        nodes << self.select_node(
          grid_service, i + 1, available_nodes
        )
      rescue Scheduler::Error
      end
    end
    filtered_count = nodes.uniq.size
    self.strategy.instance_count(filtered_count,grid_service.container_count)
  end

  # @param [GridService] grid_service
  # @param [Integer] instance_number
  # @param [Array<Scheduler::Node>] nodes
  # @raise [Scheduler::Error]
  # @return HostNode
  def select_node(grid_service, instance_number, nodes)
    if nodes.empty?
      raise Scheduler::Error, "There are no nodes available"
    end

    selected_node = nil
    @mutex.synchronize {
      filtered_nodes = self.filter_nodes(grid_service, instance_number, nodes)
      selected_node = self.strategy.find_node(grid_service, instance_number, filtered_nodes)
    }
    unless selected_node
      raise Scheduler::Error, "Strategy #{self.strategy.class.to_s} did not find any node"
    end
  
    node = nodes.find{ |n| n == selected_node }
    node.schedule_counter += 1

    selected_node
  end

  # @param [GridService] grid_service
  # @param [Integer] instance_number
  # @param [Array<Scheduler::Node>]
  # @raise [Scheduler::Error]
  # @return [Array<HostNode>]
  def filter_nodes(grid_service, instance_number, nodes)
    self.filters.each do |filter|
      nodes = filter.for_service(grid_service, instance_number, nodes)

      if nodes.empty?
        raise Scheduler::Error, "Filter #{filter.class.to_s} did not return any nodes"
      end
    end

    nodes
  end
end
