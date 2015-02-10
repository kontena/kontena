require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
  class Api
    include Kontena::Cli::Common

    def init
      api_url = ask('Kontena server url: [https://api.kontena.io]')
      api_url = 'https://api.kontena.io' if api_url == ''
      inifile['platform']['url'] = api_url
      inifile.save(filename: ini_filename)
    end
  end
end