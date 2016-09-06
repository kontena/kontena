require 'symmetric-encryption'
require 'bcrypt'

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
      return @salt unless @salt.nil?
      encrypted_salt = config[:salt]
      if encrypted_salt
        @salt = SymmetricEncryption.decrypt(encrypted_salt)
      else
        @salt = BCrypt::Engine.generate_salt
        config[:salt] = SymmetricEncryption.encrypt(@salt)
      end
      @salt
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
