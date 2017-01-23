module Kontena::NetworkAdapters
  class WeaveExecutor
    include Celluloid
    include Kontena::Helpers::WeaveExecHelper

    def initialize(autostart = true)
      @images_exist = false
      info 'initialized'
    end
  end
end
