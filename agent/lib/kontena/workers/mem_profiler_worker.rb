require 'ruby-prof'

module Kontena::Workers
  class MemProfilerWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging


    def initialize
      @report_interval = 60 #(ENV['MEM_PROFILING_INTERVAL'] || 60).to_i
      self.async.start if ENV['MEM_PROFILING']
    end

    def start
      loop do
        debug "********** dumping heap"
        f = ObjectSpace.dump_all(output: :file)
        debug "***** dumped to: #{f.path}"
        sleep @report_interval
      end
    end

  end
end
