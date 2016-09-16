require 'symmetric-encryption'
require 'bcrypt'

module DigestHelper

  def self.included(base)
    base.send :extend, ClassMethods
  end

  def salt
    self.class.salt
  end

  def digest(string)
    self.class.digest(string)
  end

  module ClassMethods
    def salt
      return @salt unless @salt.nil?
      encrypted_salt = Configuration[:salt]
      if encrypted_salt
        @salt = SymmetricEncryption.decrypt(encrypted_salt)
      else
        @salt = BCrypt::Engine.generate_salt
        Configuration[:salt] = SymmetricEncryption.encrypt(@salt)
      end
      @salt
    end

    def digest(string)
      BCrypt::Engine.hash_secret(string, salt)
    end
  end
end
