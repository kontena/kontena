require_relative '../lib/kontena-agent'

Kontena::Logging.initialize_logger(STDERR, (ENV['LOG_LEVEL'] || Logger::WARN).to_i)

require 'ruby-prof'
require 'benchmark'
require 'active_support/core_ext/enumerable'

def getenv(name, default = nil)
  if value = ENV[name]
    value = yield value if block_given?
  else
    value = default
  end

  value
end

COUNT = getenv('COUNT', 1000) { |v| Integer(i) }
BENCHMARK = getenv('BENCHMARK')

def benchmark_main(cases, count: COUNT, before_each: nil)
  label_width = cases.keys.map{|k| k.length}.max
  stats = {}

  Benchmark.bm(label_width) do |bm|
    cases.each_pair do |label, block|
      return if BENCHMARK and label != BENCHMARK
      before_each.call if before_each
      bm.report(label) do
        futures = (1..count).map{|id| sleep 0.001; block.call(id) }
        total_delay = futures.map{|f| f.value }.sum

        stats[label] = {
          total_delay: total_delay
        }
      end
    end
  end

  puts "%-12s %12s" % ['', 'delay']
  stats.each_pair do |label, stat|
    puts '%-12s %12.6f' % [label, stat[:total_delay]]
  end
end

def benchmark(cases, **options)
  if profile = getenv('PROFILE')
    measure_mode = getenv('PROFILE_MODE', RubyProf::WALL_TIME) { |x| RubyProf.const_get(x.upcase.to_sym) }
    sort_method = getenv('PROFILE_SORT', :total_time) { |x| "#{x}_time".to_sym}
    printer_cls = getenv('PROFILE_PRINTER', RubyProf::FlatPrinter) { |x| RubyProf.const_get("#{x.capitalize}Printer".to_sym) }
    merge_fibers = getenv('PROFILE_MERGE_FIBERS', true) { |x| {'false' => false, 'true' => true}.fetch(x) }

    result = RubyProf.profile(measure_mode: measure_mode, merge_fibers: merge_fibers) do
      benchmark_main(cases, **options)
    end

    printer_cls.new(result).print(STDOUT, sort_method: sort_method)
  else
    benchmark_main(cases, **options)
  end
end
