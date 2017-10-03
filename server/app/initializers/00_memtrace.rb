if trace_path = ENV['TRACE_ALLOCS']
  require 'objspace'
  ObjectSpace.trace_object_allocations_start

  $stderr.puts "Tracing object allocations, dump on SIGTTOU to #{trace_path}"
  Signal.trap("TTOU") do
    # break out of trap context
    Thread.new do
      $stderr.puts "Dumping object allocations to #{trace_path}..."
      begin
        GC.start
        File.open(trace_path, "w") do |f|
          ObjectSpace.dump_all(output: f)
        end
      rescue Exception => exc
        $stderr.puts "Object dump failed: #{exc} @ #{exc.backtrace.join("\n\t")}"
      else
        $stderr.puts "Object dump complete"
      end
    end
  end
end
