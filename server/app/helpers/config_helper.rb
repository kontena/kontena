module ConfigHelper

  def self.included(base)
    base.send :extend, ClassMethods
  end

  def config
    self.class.config
  end

  module ClassMethods
    def config
      Configuration
    end
  end
end
