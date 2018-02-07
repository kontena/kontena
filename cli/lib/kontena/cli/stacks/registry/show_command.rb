require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Shows information about a stack on the stacks registry"

    option ['-v', '--versions'], :flag, "Only list available versions"

    requires_current_account_token

    def execute
      unless versions?
        data = stacks_client.show(stack_name).dig('data', 'attributes')
        puts "#{data['organization-id']}/#{data['name']}:"
        puts "  description: #{data.dig('latest-version', 'description') || '-'}"
        puts "  latest_version: #{data.dig('latest-version', 'version') || '-'}"
        puts "  created_at: #{data.dig('created-at')}"
        puts "  pulls: #{data.dig('pulls')}"
        puts "  private: #{data.dig('is-private')}"
        print "  meta:"
        meta = data.dig('latest-version', 'meta')
        if meta
          puts
          readme = meta.delete('readme')
          meta_lines = YAML.dump(meta).split(/[\r\n]/)
          meta_lines.shift
          meta_lines.each do |meta_line|
            puts "    %s" % meta_line
          end
          if readme
            if readme =~ /^http\S+$/
              puts "    readme: readme"
            else
              puts "    readme: |"
              readme.gsub!(/(\S{#{70}})(?=\S)/, '\1 ')
              readme.gsub!(/(.{1,#{70}})(?:\s+|$)/, "\\1\n")
              readme.gsub!(/^/, '      ')
              puts readme
            end
          end
        else
          puts "-"
        end

        puts "  versions:"
      end

      stacks_client.versions(stack_name).each do |version|
        puts versions? ? version['attributes']['version'] : "    - #{version['attributes']['version']} (#{version['attributes']['created-at']})"
      end
    end
  end
end
