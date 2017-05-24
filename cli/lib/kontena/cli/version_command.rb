require 'kontena/cli/version'

class Kontena::Cli::VersionCommand < Kontena::Command
  include Kontena::Cli::Common

  option "--cli", :flag, "Only CLI version"
  option "--subcommand-tree", :flag, "Print out full subcommand tree", hidden: true

  def execute
    return subcommand_tree if subcommand_tree?
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

  def subcommand_tree(cmd = "kontena", base = Kontena::MainCommand)
    puts "#{cmd} "
    if base.has_subcommands?
      base.recognised_subcommands.each do |sc|
        subcommand_tree("#{cmd} #{sc.names.first}", sc.subcommand_class)
      end
    end
  end
end
