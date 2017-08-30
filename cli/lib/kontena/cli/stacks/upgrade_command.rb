require_relative 'common'

module Kontena::Cli::Stacks
  class UpgradeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Upgrades a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    include Common::StackFileOrNameParam

    include Common::StackValuesToOption
    include Common::StackValuesFromOption

    option '--[no-]deploy', :flag, 'Trigger deploy after upgrade', default: true

    option '--force', :flag, 'Force upgrade'
    option '--skip-dependencies', :flag, "Do not install any stack dependencies"

    requires_current_master
    requires_current_master_token

    def normalize_local_data(stack_data, parent_name)
      return nil if stack_data.nil? || stack_data.empty?

      depends = stack_data.delete(:depends) || []
      normalized_data = {
        parent_name => stack_data.merge(
          loader: loader_class.for(stack_data[:stack])
        )
      }

      depends.each do |stack|
        key = "#{parent_name}-#{stack[:name]}"
        normalized_data.merge!(normalize_local_data(stack.merge(parent_name: parent_name), key))
      end
      normalized_data
    end

    def normalize_master_data(stack_name)
      begin
        data = fetch_master_data(stack_name)
      rescue Kontena::Errors::StandardError => ex
        return nil if ex.status == 404
        raise ex
      end
      depends = data.delete('children') || []

      normalized_data = { stack_name => data }

      return normalized_data if skip_dependencies?

      depends.each do |stack|
        normalized_data.merge!(normalize_master_data(stack['name']))
      end
      normalized_data
    end

    def merge_data(local_data, remote_data)
      merged = {}
      unless local_data.nil? || local_data.empty?
        local_data.each do |key, data|
          merged[key] ||= {}
          merged[key][:local] = data
        end
      end
      unless remote_data.nil? || remote_data.empty?
        remote_data.each do |key, data|
          merged[key] ||= {}
          merged[key][:remote] = data
        end
      end
      merged
    end

    def execute

      local = spinner "Parsing #{pastel.cyan(source)}" do
        normalize_local_data({stack: source, depends: skip_dependencies? ? nil : loader.dependencies}, stack_name)
      end

      remote = spinner "Reading stack #{pastel.cyan(stack_name)} from master" do
        normalize_master_data(stack_name)
      end

      merged = merge_data(local, remote)

      removes = merged.keys.select { |k| merged[k][:local].nil? }

      unless removes.empty?
        puts
        puts "Stacks to be removed because they are no longer depended on:"
        removes.each do |r|
          puts pastel.yellow("- #{r}")
        end
        puts
        unless force?
          puts "#{pastel.red('Warning:')} This can not be undone, data will be lost."
        end
        confirm unless force?
        removes.reverse_each do |r|
          Kontena.run!('stack', 'remove', '--force', '--keep-dependent', r)
          merged.delete(r)
        end
      end

      unless force?
        merged.each do |stackname, data|
          next if data[:remote].nil?
          unless data[:local][:loader].stack_name.stack_name == data[:remote]['stack']
            confirm "Replacing stack #{pastel.cyan(data[:remote]['stack'])} on master with #{pastel.cyan(data[:local][:loader].stack_name.stack_name)}. Are you sure?"
          end
        end
      end

      merged.reverse_each do |stackname, data|
        set_env_variables(stackname, current_grid)
        stack = data[:local][:loader].reader.execute(
          name: stackname,
          values: (data.dig(:local, :variables) || {}).merge(dependency_values_from_options(stackname)),
          defaults: data.dig(:remote, 'variables'),
          parent_name: data.dig(:local, :parent_name)
        )

        if data[:remote]
          spinner "Upgrading #{stack_name == stackname ? 'stack' : 'dependency'} #{pastel.cyan(stackname)}" do |spin|
            update_stack(stackname, stack.reject { |k, _| [:errors, :notifications, :parent_name].include?(k) }) || spin.fail!
          end
        else
          cmd = ['stack', 'install', '--name', stackname]
          cmd.concat ['--parent-name', stack[:parent_name]] if stack[:parent_name]
          stack[:variables].merge(dependency_values_from_options(stackname)).each do |k, v|
            cmd.concat ['-v', "#{k}=#{v}"]
          end
          cmd << '--no-deploy'
          cmd << data[:local][:loader].source
          caret "Installing new dependency #{cmd.last} as #{stackname}"
          Kontena.run!(cmd)
        end

        Kontena.run!(['stack', 'deploy', stackname]) if deploy?
      end
    end

    def update_stack(name, data)
      client.put(stack_url(name), data)
    end

    def stack_url(name)
      "stacks/#{current_grid}/#{name}"
    end

    def fetch_master_data(stack_name)
      client.get(stack_url(stack_name))
    end
  end
end
