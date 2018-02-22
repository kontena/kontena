module CelluloidMailboxTracer
  def <<(message)
    $stderr.puts "Celluloid::Mailbox<@#{Thread.current[:celluloid_actor]}> << #{message.class.name} \n\t#{caller.join("\n\t")}\n"
    super
  end
end

module CelluloidSyncCallTracer
  def method_missing(method, *args, &block)
    actor = Thread.current[:celluloid_actor]
    subject = actor ? actor.behavior_proxy.__klass__ : nil

    t = Time.now
    $stderr.puts "TRACE SYNC CALL #{subject} -> #{__klass__}##{method} @\n\t#{caller.join("\n\t")}"

    ret = super
    dt = Time.now - t

    $stderr.puts "TRACE SYNC CALL #{subject} <- #{__klass__}##{method} => #{ret.class} in #{'%.3fs' % dt}"

    ret
  end
end

module CelluloidAsyncCallTracer
  def method_missing(method, *args, &block)
    actor = Thread.current[:celluloid_actor]
    subject = actor ? actor.behavior_proxy.__klass__ : nil

    $stderr.puts "TRACE ASYNC CALL #{subject} -> #{__klass__}##{method} @ #{Celluloid.current_actor}\n\t#{caller.join("\n\t")}"

    super
  end
end

if ENV['TRACE_CELLULOID'].split.include? 'mailbox'
  class Celluloid::Mailbox
    $stderr.puts "TRACE CELLULOID MAILBOX"

    prepend ::CelluloidMailboxTracer
  end
end

if ENV['TRACE_CELLULOID'].split.include? 'sync'
  class Celluloid::Proxy::Sync
    prepend ::CelluloidSyncCallTracer
  end
end

if ENV['TRACE_CELLULOID'].split.include? 'async'
  class Celluloid::Proxy::Async
    prepend ::CelluloidAsyncCallTracer
  end
end
