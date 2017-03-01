module Rpc
  class NodeServiceHandler
    include Celluloid

    def initialize(grid)
      @grid = grid
    end

    def list(id)
      []
    end
  end
end
