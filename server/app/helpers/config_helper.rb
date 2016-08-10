module ConfigHelper
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

  # Get or generate a global salt
  def self.salt
    return @salt if @salt
    @salt = config[:salt] ||= BCrypt::Engine.generate_salt
  end

  def self.encrypt(string)
    BCrypt::Engine.hash_secret(string, salt)
  end
 
end
