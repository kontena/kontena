Dir[__dir__ + '/scheduler/**/*.rb'].each {|file| require file }
Dir[__dir__ + '/docker/*.rb'].each {|file| require file }

class GridServiceScheduler

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

  ##
  # @param [GridService] grid_service
  # @param [Integer] instance_number
  # @param [Array<HostNode>] nodes
  def select_node(grid_service, instance_number, nodes)
    nodes = self.filter_nodes(grid_service, instance_number, nodes)
    self.strategy.find_node(grid_service, instance_number, nodes)
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
