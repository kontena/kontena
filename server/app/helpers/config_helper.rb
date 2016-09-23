module ConfigHelper

  def self.included(base)
    base.send :extend, ClassMethods
  end

  def config
    self.class.config
  end

  module ClassMethods
    def config
      return @config if @config
      @config = Configuration
      @config.seed(Server.root.join('config/seed.yml'))
      @config
    end
  end
end
