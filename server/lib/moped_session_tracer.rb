require 'moped'
require_relative 'thread_tracer'

class Moped::Session
  # Check that each Moped::Session is only accessed by the same thread that created it
  module Tracer
    def initialize(seeds, options = {})
      @thread_tracer = ThreadTracer.new("Moped::Session[#{@db_session.object_id}]")
      super
    end

    def current_database
      @thread_tracer.check!
      super
    end
  end

  prepend Tracer

  ThreadTracer.debug { "TRACE Moped::Session @ #{ThreadTracer.caller}" }
end
