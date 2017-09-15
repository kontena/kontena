module FiberTracer
  module ClassMethods
    def new(*args)
      $stderr.puts "FIBER CREATE #{self.name}: #{args.first.class.name} \n\t#{caller.join("\n\t")}\n"
      super
    end

    def yield(*args)
      $stderr.puts "FIBER YIELD #{self.name} <- #{args.first.class.name} \n\t#{caller.join("\n\t")}\n"
      out = super
      $stderr.puts "FIBER YIELD #{self.name} -> #{out.class.name}\n\t#{caller.join("\n\t")}\n"
      out
    end
  end

  def resume(*args)
    $stderr.puts "FIBER RESUME #{self.class.name} <- #{args.first.class.name}\n\t#{caller.join("\n\t")}\n"
    out = super
    $stderr.puts "FIBER RESUME #{self.class.name} -> #{out.class.name}\n\t#{caller.join("\n\t")}\n"
    out
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
