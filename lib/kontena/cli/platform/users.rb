require 'kontena/client'
require_relative '../common'
require 'pp'

module Kontena::Cli::Platform
  class Users
    include Kontena::Cli::Common

    def add(email)
      require_api_url
      data = { email: email }
      result = client(token).post("grids/#{current_grid}/users", data)
      result['users'].each { |user| puts user['email'] }
    end

    def remove(email)
      require_api_url

      result = client(token).delete("grids/#{current_grid}/users/#{email}")
      result['users'].each { |user| puts user['email'] }
    end

    def list
      result = client(token).get("grids/#{current_grid}/users")
      result['users'].each { |user| puts user['email'] }
    end

    private

    def token
      @token ||= require_token
    end

    def current_grid
      inifile['platform']['grid']
    end
  end
end