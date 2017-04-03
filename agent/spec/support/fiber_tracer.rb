module FiberTracer
  module ClassMethods
    def yield(*args)
      $stderr.puts "FIBER YIELD <- \n\t#{caller.join("\n\t")}\n"
      out = super
      $stderr.puts "FIBER YIELD ->\n\t#{caller.join("\n\t")}\n"
      out
    end
  end

  def resume(*args)
    #$stderr.puts "FIBER RESUME:\n\t#{caller.join("\n\t")}\n"
    super
  end

  def self.prepended(base)
    class << base
      prepend ClassMethods
    end
  end
end

class Fiber
  prepend FiberTracer
end
