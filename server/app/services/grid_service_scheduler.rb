require_glob __dir__ + '/scheduler/**/*.rb'
require_glob __dir__ + '/docker/*.rb'

class GridServiceScheduler

  STRATEGIES = {
      'ha' => Scheduler::Strategy::HighAvailability,
      'daemon' => Scheduler::Strategy::Daemon,
      'random' => Scheduler::Strategy::Random
  }.freeze

  attr_reader :strategy, :filters

  ##
  # @param [#find_node] strategy
  def initialize(strategy)
    @strategy = strategy
    @filters = [
        Scheduler::Filter::Affinity.new,
        Scheduler::Filter::Port.new,
        Scheduler::Filter::Memory.new,
        Scheduler::Filter::Dependency.new
    ]
    @mutex = Mutex.new
  end

  # @param [Integer] node_count
  # @param [Integer] instance_count
  # @return [Integer]
  def instance_count(node_count, instance_count)
    self.strategy.instance_count(node_count, instance_count)
  end

  ##
  # @param [GridService] grid_service
  # @param [Integer] instance_number
  # @param [Array<HostNode>] nodes
  # @return [HostNode, NilClass]
  def select_node(grid_service, instance_number, nodes)
    selected_node = nil
    @mutex.synchronize {
      filtered_nodes = self.filter_nodes(grid_service, instance_number, nodes)
      selected_node = self.strategy.find_node(grid_service, instance_number, filtered_nodes)
    }
    if selected_node
      node = nodes.find{|n| n == selected_node}
      node.schedule_counter += 1
    end

    selected_node
  end

  ##
  # @param [GridService] grid_service
  # @param [Integer] instance_number
  # @param [Array<HostNode>]
  # @return [Array<HostNode>]
  def filter_nodes(grid_service, instance_number, nodes)
    self.filters.each do |filter|
      nodes = filter.for_service(grid_service, instance_number, nodes)
    end

    nodes
  end
end
