module CelluloidCallTracer
  def method_missing(method, *args, &block)
    t = Time.now
    $stderr.puts "CELLULOID #{__class__} CALL -> #{__klass__}##{method} @\n\t#{caller.join("\n\t")}"

    ret = super
    dt = Time.now - t

    $stderr.puts "CELLULOID #{__class__} CALL <- #{__klass__}##{method} => #{ret.class} in #{'%.3fs' % dt}"

    ret
  end
end

class Celluloid::Proxy::Sync
  prepend ::CelluloidCallTracer if ::ENV['TRACE_CELLULOID_CALLS'] == 'sync'
end
