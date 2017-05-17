require 'kontena/cli/version'

class Kontena::Cli::VersionCommand < Kontena::Command
  include Kontena::Cli::Common

  option "--cli", :flag, "Only CLI version"

  def execute
    puts "cli: #{Kontena::Cli::VERSION}"
    return if cli?

    url = api_url rescue nil
    if url
      resp = JSON.parse(client.http_client.get(path: '/').body) rescue nil
      if resp
        puts "master: #{resp['version']} (#{url})"
      end
    end
  end
end
