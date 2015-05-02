Dir[__dir__ + '/scheduler/**/*.rb'].each {|file| require file }
Dir[__dir__ + '/docker/*.rb'].each {|file| require file }

class GridScheduler

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
  # @param [String] container_name
  # @param [Array<HostNode>] nodes
  def select_node(grid_service, container_name, nodes)
    nodes = self.filter_nodes(grid_service, container_name, nodes)
    self.strategy.find_node(grid_service, container_name, nodes)
  end

  ##
  # @param [GridService] grid_service
  # @param [String] name
  # @param [Array<HostNode>]
  # @return [Array<HostNode>]
  def filter_nodes(grid_service, name, nodes)
    self.filters.each do |filter|
      nodes = filter.for_service(grid_service, name, nodes)
    end

    nodes
  end
end
