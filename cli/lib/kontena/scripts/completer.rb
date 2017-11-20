require 'kontena/cli/common'

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

  def client
    $VERSION_WARNING_ADDED=true
    token = require_token
    super(token)
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
        sub_commands = %w(list ls search install uninstall)
        if words[1]
          completion.push(sub_commands) unless sub_commands.include?(words[1])
        else
          completion.push sub_commands
        end
      when 'etcd'
        completion.clear
        sub_commands = %w(get set mkdir mk list ls rm)
        if words[1]
          completion.push(sub_commands) unless sub_commands.include?(words[1])
        else
          completion.push sub_commands
        end
      when 'registry'
        completion.clear
        sub_commands = %w(create remove rm)
        if words[1]
          completion.push(sub_commands) unless sub_commands.include?(words[1])
        else
          completion.push sub_commands
        end
      when 'grid'
        completion.clear
        sub_commands = %w(add-user audit-log create current list user remove show use)
        if words[1] && words[1] == 'use'
          completion.push helper.grids.reject { |g| g == helper.current_grid }
        elsif words[1] && %w(update show rm remove env cloud-config health).include?(words[1])
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
        sub_commands = %w(list use user current remove rm config cfg login logout token join audit-log init-cloud)
        if words[1] && words[1] == 'use'
          completion.push helper.master_names.reject { |n| n == helper.current_master_name }
        elsif words[1] && %w(remove rm).include?(words[1])
          completion.push helper.master_names
        elsif words[1] && words[1] == 'user'
          users_sub_commands = %w(invite list role)
          if words[2] == 'role'
            role_subcommands = %w(add remove rm)
            if !words[3] || !role_subcommands.include?(words[3])
              completion.push role_subcommands
            end
          else
            completion.push users_sub_commands
          end
        elsif words[1] && ['config', 'cfg'].include?(words[1])
          config_sub_commands = %(set get dump load import export unset)
          completion.push config_sub_commands
        elsif words[1] && words[1] == 'token'
          token_sub_commands = %(list ls rm remove show current create)
          completion.push token_sub_commands
        elsif words[1]
          completion.push(sub_commands) unless sub_commands.include?(words[1])
        else
          completion.push sub_commands
        end
      when 'cloud'
        completion.clear
        sub_commands = %w(login logout master)
        if words[1] && words[1] == 'master'
          cloud_master_sub_commands = %(list ls remove rm add show update)
          completion.push cloud_master_sub_commands
        elsif words[1]
          completion.push(sub_commands) unless sub_commands.include?(words[1])
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
      when 'app'
        completion.clear
        sub_commands = %w(init build config deploy start stop remove rm ps list
                          logs monitor show)
        if words[1] && sub_commands.include?(words[1])
          completion.push helper.yml_services
        else
          completion.push sub_commands
        end
      when 'stack'
        completion.clear
        sub_commands = %w(build install upgrade deploy start stop remove rm ls list
                          logs monitor show registry)
        if words[1]
          if words[1] == 'registry'
            registry_sub_commands = %(push pull search show rm)
            completion.push registry_sub_commands
          elsif %w(install).include?(words[1])
              completion.push helper.yml_files
          elsif words[1] == 'upgrade' && words[3]
            completion.push helper.yml_files
          elsif words[1] && sub_commands.include?(words[1])
            completion.push helper.stacks
          else
            completion.push(sub_commands)
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
