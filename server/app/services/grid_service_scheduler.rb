Dir[__dir__ + '/scheduler/**/*.rb'].each {|file| require file }
Dir[__dir__ + '/docker/*.rb'].each {|file| require file }

class GridServiceScheduler

  STRATEGIES = {
      'ha' => Scheduler::Strategy::HighAvailability,
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
        Scheduler::Filter::Dependency.new
    ]
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
  # @param [String] rev
  # @return [HostNode, NilClass]
  def select_node(grid_service, instance_number, nodes, rev = nil)
    nodes = self.filter_nodes(grid_service, instance_number, nodes)
    self.strategy.find_node(grid_service, instance_number, nodes, rev)
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
