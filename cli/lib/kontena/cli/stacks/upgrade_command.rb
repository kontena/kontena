require 'json'
require 'kontena/stacks/change_resolver'
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
    option '--skip-dependencies', :flag, "Do not upgrade any stack dependencies", default: false
    option '--reuse-values', :flag, "Reuse existing values"
    option '--dry-run', :flag, "Simulate upgrade"

    requires_current_master
    requires_current_master_token

    # @return [Kontena::Stacks::ChangeResolver]
    def execute
      old_data = spinner "Reading stack #{pastel.cyan(stack_name)} from master" do
        gather_master_data(stack_name)
      end

      kontena_requirement = loader.yaml.dig('meta', 'required_kontena_version')
      unless kontena_requirement.nil?
        master_version = Gem::Version.new(client.server_version)
        unless Gem::Requirement.new(kontena_requirement).satisfied_by?(master_version)
          puts "#{pastel.red("Warning: ")} Stack requires kontena version #{kontena_requirement} but Master version is #{master_version}"
          confirm("Are you sure? You can skip this prompt by running this command with --force option") unless force?
        end
      end

      new_data = spinner "Parsing #{pastel.cyan(source)}" do
        loader.flat_dependencies(
          stack_name,
          variables: values_from_options
        )
      end

      changes = process_data(old_data, new_data)

      display_report(changes)

      return changes if dry_run?

      confirm("#{pastel.red('Warning:')} This can not be undone, data will be lost.") unless changes.safe?

      deployable_stacks = []
      deployable_stacks.concat run_installs(changes)
      deployable_stacks.concat run_upgrades(changes)

      run_deploys(deployable_stacks) if deploy?

      run_removes(changes.stacks.removed)

      changes
    end

    private

    # Recursively fetch master data in StackFileLoader#flat_dependencies format
    # @return [Hash{string => Hash}] stackname => hash
    def gather_master_data(stackname)
      response = fetch_master_data(stackname)
      children = response.delete('children') || []
      result = { stackname => { stack_data: response } }
      children.each do |child|
        result.merge!(gather_master_data(child['name']))
      end
      result
    end

    # Preprocess data and return a ChangeResolver ResultSet
    # @param old_data [Hash] data from master
    # @param new_data [Hash] data from files
    # @return [Kontena::Cli::Stacks::ChangeRsolver::ResultSet]
    def process_data(old_data, new_data)
      logger.debug { "Master stacks: #{old_data.keys.join(",")} YAML stacks: #{new_data.keys.join(",")}" }

      new_data.reverse_each do |stackname, data|
        spinner "Processing stack #{pastel.cyan(stackname)}"
        process_stack_data(stackname, data, old_data)
        hint_on_validation_notifications(reader.notifications, reader.loader.source)
        abort_on_validation_errors(reader.errors, reader.loader.source)
      end

      old_set = Kontena::Stacks::StackDataSet.new(old_data)
      new_set = Kontena::Stacks::StackDataSet.new(new_data)
      if skip_dependencies?
        [old_set, new_set].each(&:remove_dependencies)
      end
      spinner "Analyzing upgrade" do
        Kontena::Stacks::ChangeResolver.new(old_set).compare(new_set)
      end
    end

    # @param stackname [String]
    # @param data [Hash]
    # @param old_data [Hash]
    def process_stack_data(stackname, data, old_data)
      prev_env = ENV.clone
      reader = data[:loader].reader
      values = data[:variables]
      if reuse_values? && old_data[stackname]
        old_vars = old_data[stackname][:stack_data]['variables']
        values = old_vars.merge(values)
      end
      set_env_variables(stackname, current_grid) # set envs for execution time
      parsed_stack = reader.execute(
        values: values,
        defaults: old_data[stackname].nil? ? nil : old_data[stackname][:stack_data]['variables'],
        parent_name: data[:parent_name],
        name: data[:name]
      )
      data[:stack_data] = parsed_stack
    ensure
      ENV.update(prev_env)
    end

    # @param changes [Kontena::Stacks::ChangeResolver]
    def display_report(changes)
      puts
      caret "Calculated changes:", dots: false

      changes.stacks.removed.each do |stack|
        puts "  #{pastel.red('-')} #{stack}"
        changes.services[stack].removed.each do |s|
          puts "    #{pastel.red('-')} #{s}"
        end
      end

      unless changes.stacks.replaced.empty?
        changes.stacks.replaced.each do |stack|
          puts "  #{pastel.yellow('-/+')} #{stack}"
          changes.services[stack].upgraded.each do |s|
            puts "    #{pastel.cyan('~')} #{stack}/#{s}"
          end
          changes.services[stack].added.each do |s|
            puts "    #{pastel.green('+')} #{stack}/#{s}"
          end
          changes.services[stack].removed.each do |s|
            puts "    #{pastel.red('-')} #{stack}/#{s}"
          end
        end
        changes.stacks.replaced.each do |installed_name, data|
          puts "- #{pastel.yellow(installed_name)} from #{pastel.cyan(data[:from])} to #{pastel.cyan(data[:to])}"
        end
        puts
      end

      unless changes.stacks.added.empty?
        changes.stacks.added.each do |stack|
          puts "  #{pastel.green('+')} #{stack}"
          changes.services[stack].added.each do |s|
            puts "    #{pastel.green('+')} #{stack}/#{s}"
          end
        end
      end

      unless changes.stacks.upgraded.empty?
        changes.stacks.upgraded.each do |stack|
          puts "  #{pastel.cyan('~')} #{stack}"
          changes.services[stack].upgraded.each do |s|
            puts "    #{pastel.cyan('~')} #{stack}/#{s}"
          end
          changes.services[stack].added.each do |s|
            puts "    #{pastel.green('+')} #{stack}/#{s}"
          end
          changes.services[stack].removed.each do |s|
            puts "    #{pastel.red('-')} #{stack}/#{s}"
          end
        end
      end
      puts
    end

    def deployable_stacks
      @deployable_stacks ||= []
    end

    # @param removed_stacks [Array<String>]
    def run_removes(removed_stacks)
      removed_stacks.reverse_each do |removed_stack|
        Kontena.run!('stack', 'remove', '--force', '--keep-dependencies', removed_stack)
      end
    end

    # @param changes [Kontena::Stacks::ChangeResolver]
    # @return [Array] an array of stack names that have been installed, but not yet deployed
    def run_installs(changes)
      deployable_stacks = []
      changes.stacks.added.reverse_each do |added_stack|
        data = changes.new_data[added_stack]
        cmd = ['stack', 'install', '--name', added_stack, '--no-deploy']
        cmd.concat ['--parent-name', data.parent] unless data.root?
        data.variables.each do |k,v|
          cmd.concat ['-v', "#{k}=#{v}"]
        end
        cmd << data.loader.source
        caret "Installing new dependency #{cmd.last} as #{added_stack}"
        deployable_stacks << added_stack
        Kontena.run!(cmd)
      end
      deployable_stacks
    end

    # @param changes [Kontena::Stacks::ChangeResolver]
    # @return [Array] an array of stack names that have been upgraded, but not yet deployed
    def run_upgrades(changes)
      deployable_stacks = []
      changes.stacks.upgraded.reverse_each do |upgraded_stack|
        data = changes.new_data[upgraded_stack]
        spinner "Upgrading #{data.root? ? 'stack' : 'dependency'} #{pastel.cyan(upgraded_stack)}" do |spin|
          deployable_stacks << upgraded_stack
          update_stack(upgraded_stack, data.data) || spin.fail!
        end
      end
      deployable_stacks
    end

    # @param deployable_stacks [Array<String>] an array of stack names that should be deployed
    def run_deploys(deployable_stacks)
      deployable_stacks.each do |deployable_stack|
        Kontena.run!(['stack', 'deploy', deployable_stack])
      end
    end

    def update_stack(name, data)
      client.put(stack_url(name), data)
    end

    def stack_url(name)
      "stacks/#{current_grid}/#{name}"
    end

    def fetch_master_data(stackname)
      client.get(stack_url(stackname))
    end
  end
end
