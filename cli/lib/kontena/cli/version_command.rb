require_relative 'version'

class Kontena::Cli::VersionCommand < Kontena::Command
  include Kontena::Cli::Common

  def execute
    url = api_url rescue nil
    puts "cli: #{Kontena::Cli::VERSION}"
    if url
      resp = JSON.parse(client.http_client.get(path: '/').body) rescue nil
      if resp
        puts "master: #{resp['version']} (#{url})"
      end
    end
  end
end
