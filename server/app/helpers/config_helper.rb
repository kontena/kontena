# Helpers for accessing the Configuration model
module ConfigHelper

  def self.included(base)
    base.send :extend, ClassMethods
  end

  # Global encryption salt.
  #
  # @return [String] salt
  def salt
    self.class.salt
  end

  # Encrypt a string using BCrypt and the global salt from ConfigHelper#salt
  #
  # @param [String] string_to_be_encrypted
  # @return [String] encrypted_string
  def encrypt(string)
    self.class.encrypt(string)
  end

  # Accessor to the config
  def config
    self.class.config
  end

  module ClassMethods
    # Global encryption salt.
    #
    # @return [String] salt
    def salt
      return @salt if @salt
      @salt = config[:salt] ||= BCrypt::Engine.generate_salt
    end

    # Encrypt a string using BCrypt and the global salt from ConfigHelper#salt
    #
    # @param [String] string_to_be_encrypted
    # @return [String] encrypted_string
    def encrypt(string)
      BCrypt::Engine.hash_secret(string, salt)
    end

    # Accessor to the config.
    def config
      return @config if @config
      if Object::const_defined?('Server')
        @config = Server.config
      elsif Object::const_defined?('Configuration')
        @config = Configuration
      end
    end
  end
end
