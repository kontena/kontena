module ConfigHelper

  def self.included(base)
    base.send :extend, ClassMethods
  end

  def salt
    self.class.salt
  end

  def encrypt(string)
    self.class.encrypt(string)
  end

  def config
    self.class.config
  end

  module ClassMethods
    def salt
      return @salt if @salt
      @salt = config[:salt] ||= BCrypt::Engine.generate_salt
    end

    def encrypt(string)
      BCrypt::Engine.hash_secret(string, salt)
    end
    
    def config
      return @config if @config
      if Object::const_defined?('Server')
        @config = Server.config
      elsif Object::const_defined?('Configuration')
        @config = Configuration
      else
        require 'ostruct'
        @config = OpenStruct.new
      end
    end
  end
end
