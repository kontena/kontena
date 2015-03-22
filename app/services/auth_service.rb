module AuthService
  def self.setup
    yield self
  end
  class << self
    attr_accessor :api_url
  end
end