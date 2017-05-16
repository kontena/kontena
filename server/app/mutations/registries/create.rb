require 'uri'

module Registries
  class Create < Mutations::Command

    required do
      model :grid
      string :url, matches: /\Ahttps?:\/\/[\S]+\z/
      string :username
      string :password
      string :email
    end

    def execute
      uri = URI.parse(self.url)
      unless [80, 443].include?(uri.port)
        name = "#{uri.host}:#{uri.port}"
      else
        name = uri.host
      end

      self.grid.registries.create(
          name: name,
          url: self.url,
          username: self.username,
          password: self.password,
          email: self.email
      )
    end
  end
end
