require 'kontena/cli/common'
require 'kontena/stacks_client'

class Helper
  include Kontena::Cli::Common

  def client_config
    require 'json'
    config_file = File.expand_path('~/.kontena_client.json')
    if(File.exist?(config_file))
      JSON.parse(File.read(config_file))
    else
      {}
    end
  rescue => ex
    logger.debug ex
    {}
  end

  def current_grid
    client_config['servers'].find { |s| s['name'] == client_config['current_server']}['grid']
  rescue => ex
    logger.debug ex
    nil
  end

  def current_master_name
    client_config['current_server']
  end

  def grids
    client.get("grids")['grids'].map{|grid| grid['id']}
  rescue => ex
    logger.debug ex
    []
  end

  def nodes
    client.get("grids/#{current_grid}/nodes")['nodes'].map{|node| node['name']}
  rescue
    []
  end

  def stacks
    stacks = client.get("grids/#{current_grid}/stacks")['stacks']
    results = []
    results.push stacks.map{|s| s['name']}
    results.delete('null')
    results
  rescue => ex
    logger.debug ex
    []
  end

  def stack_registry_usable?
    return false if current_account.nil? || current_account.stacks_url.nil?
    return false if current_account.stacks_read_authentication && current_account.token.nil? || current_account.token.access_token.nil?
    true
  end

  def stacks_client
    Kontena::StacksClient.new(current_account.stacks_url, current_account.token, read_requires_token: current_account.stacks_read_authentication)
  end

  def registry_stacks(query = '')
    return [] unless stack_registry_usable?
    results = stacks_client.search(query).map { |s| s['stack'] }
    if results.empty? && !query.empty? # this is here because old stack registry does not return anything for "org/"
      results = stacks_client.search('').map { |s| s['stack'] }.select { |s| s.start_with?(query) }
    end
    results
  rescue => ex
    logger.debug ex
    []
  end

  def registry_stack_versions(stackname)
    return [] unless stack_registry_usable?
    logger.debug stackname.inspect
    stacks_client.versions(stackname).map { |v| [stackname, v['version']].join(':') }
  rescue => ex
    logger.debug ex
    []
  end

  def services
    services = client.get("grids/#{current_grid}/services")['services']
    results = []
    results.push services.map{ |s|
      stack = s['stack']['id'].split('/').last
      if stack != 'null'
        "#{stack}/#{s['name']}"
      else
        s['name']
      end
    }
    results
  rescue => ex
    logger.debug ex
    []
  end

  def containers
    results = []
    client.get("grids/#{current_grid}/services")['services'].each do |service|
      containers = client.get("services/#{service['id']}/containers")['containers']
      results.push(containers.map{|c| c['name'] })
      results.push(containers.map{|c| c['id'] })
    end
    results
  rescue => ex
    logger.debug ex
    []
  end

  def yml_services
    require 'yaml'
    if File.exist?('kontena.yml')
      yaml = YAML.safe_load(File.read('kontena.yml'), [], [], true, 'kontena.yml')
      services = yaml['services']
      services.keys
    end
  rescue => ex
    logger.debug ex
    []
  end

  def yml_files
    Dir["./*.yml"].map{|file| file.sub('./', '')}
  rescue => ex
    logger.debug ex
    []
  end

  def master_names
    client_config['servers'].map{|s| s['name']}
  rescue => ex
    logger.debug ex
    []
  end

  def subcommand_tree(cmd = nil, base = nil)
    puts "#{cmd} ".strip
    if base.has_subcommands?
      base.recognised_subcommands.each do |sc|
        subcommand_tree("#{cmd} #{sc.names.first}", sc.subcommand_class)
      end
    end
  end
end

helper = Helper.new

words = ARGV

if words.first == '--subcommand-tree'
  require 'kontena/main_command'
  helper.subcommand_tree("kontena", Kontena::MainCommand)
  exit 0
end

words.delete_at(0)

helper.logger.debug { "Completing #{words.inspect}" }

begin
  completion = []
  completion.push %w(cloud grid app service stack vault certificate node master vpn registry container etcd external-registry whoami plugin version) if words.size < 2
  if words.size > 0
    case words[0]
      when 'plugin'
        completion.clear
        sub_commands = %w(list search install uninstall)
        if words[1]
          completion.push(sub_commands) unless (sub_commands + %w(ls)).include?(words[1])
        else
          completion.push sub_commands
        end
      when 'etcd'
        completion.clear
        sub_commands = %w(get set mkdir list rm)
        if words[1]
          completion.push(sub_commands) unless (sub_commands + %w(ls)).include?(words[1])
        else
          completion.push sub_commands
        end
      when 'registry'
        completion.clear
        sub_commands = %w(create remove)
        if words[1]
          completion.push(sub_commands) unless (sub_commands + %w(rm)).include?(words[1])
        else
          completion.push sub_commands
        end
      when 'grid'
        completion.clear
        sub_commands = %w(add-user audit-log create current list user remove show use)
        if words[1] && words[1] == 'use'
          completion.push helper.grids.reject { |g| g == helper.current_grid }
        elsif words[1] && %w(update show remove env cloud-config health).include?(words[1])
          completion.push helper.grids
        else
          completion.push sub_commands
        end
      when 'node'
        completion.clear
        sub_commands = %w(list show remove)
        if words[1] && sub_commands.include?(words[1])
          completion.push helper.nodes
        else
          completion.push sub_commands
        end
      when 'master'
        completion.clear
        sub_commands = %w(list use user current remove config login logout token join audit-log init-cloud)
        if words[1] && words[1] == 'use'
          completion.push helper.master_names.reject { |n| n == helper.current_master_name }
        elsif words[1] && %w(remove rm).include?(words[1])
          completion.push helper.master_names
        elsif words[1] && words[1] == 'user'
          users_sub_commands = %w(invite list role)
          if words[2] == 'role'
            role_subcommands = %w(add remove)
            if !words[3] || !(role_subcommands + %w(rm)).include?(words[3])
              completion.push role_subcommands
            end
          else
            completion.push users_sub_commands
          end
        elsif words[1] && ['config', 'cfg'].include?(words[1])
          config_sub_commands = %(set get dump load import export unset)
          completion.push config_sub_commands
        elsif words[1] && words[1] == 'token'
          token_sub_commands = %(list remove show current create)
          completion.push token_sub_commands
        elsif words[1]
          completion.push(sub_commands) unless (sub_commands + %w(ls rm)).include?(words[1])
        else
          completion.push sub_commands
        end
      when 'cloud'
        completion.clear
        sub_commands = %w(login logout master)
        if words[1] && words[1] == 'master'
          cloud_master_sub_commands = %(list remove add show update)
          completion.push cloud_master_sub_commands
        elsif words[1]
          completion.push(sub_commands) unless (sub_commands + %w(ls rm)).include?(words[1])
        else
          completion.push sub_commands
        end
      when 'service'
        completion.clear
        sub_commands = %w(containers create delete deploy list logs restart
                        scale show start stats stop update monitor env
                        secret link unlink)
        if words[1] && sub_commands.include?(words[1])
          completion.push helper.services
        else
          completion.push sub_commands
        end
      when 'container'
        completion.clear
        sub_commands = %w(exec inspect logs)
        if words[1] && sub_commands.include?(words[1])
          completion.push helper.containers
        else
          completion.push sub_commands
        end
      when 'vpn'
        completion.clear
        completion.push %w(config create delete)
      when 'external-registry'
        completion.clear
        completion.push %w(add list delete)
      when 'stack'
        completion.clear
        sub_commands = %w(build install upgrade deploy start stop remove restart list
                          logs monitor show registry inspect)
        if words[1]
          if words[1] == 'registry' || words[1] == 'reg'
            registry_sub_commands = %(push pull search show remove)
            if words[2]
              if words[2] == 'push'
                completion.push helper.yml_files
              elsif %w(pull search show remove rm).include?(words[2]) && words[4].nil?
                completion.push helper.registry_stacks(words[3].to_s)
              else
                completion.push registry_sub_commands
              end
            else
              completion.push registry_sub_commands
            end
          elsif %w(install validate build).include?(words[1])
            completion.push helper.yml_files
            if words[1] == 'install'
              completion.push helper.registry_stacks(words[2].to_s)
            end
          elsif words[1] == 'upgrade'
            if words[3]
              completion.push helper.yml_files
              completion.push helper.registry_stacks(words[4].to_s)
            else
              completion.push helper.stacks
            end
          elsif %w(deploy start stop remove rm restart logs monitor show inspect).include?(words[1])
            completion.push helper.stacks
          else
            completion.push(sub_commands) unless (sub_commands + %w(rm ls)).include?(words[1])
          end
        else
          completion.push sub_commands
        end
    end
  end
rescue => ex
  helper.logger.debug ex
end
helper.logger.debug { "Returning completions: #{completion.inspect}" }

puts completion
