module Celluloid
  module ExclusivePatch
    # Allow Celluloid.exclusive { ... } to be used outside of actor context: it's a no-op
    #
    #   NoMethodError:
    #     undefined method `exclusive' for nil:NilClass
    #   # celluloid-0.17.3/lib/celluloid.rb:421:in `exclusive'
    def exclusive(&block)
      if Celluloid.actor?
        super
      else
        yield
      end
    end
  end

  class << self
    # patch targets Celluloid.exclusive
    prepend ExclusivePatch
  end
end
