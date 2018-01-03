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
    option '--dry-run', :flag, "Simulate upgrade"

    requires_current_master
    requires_current_master_token

    # @return [Kontena::Stacks::ChangeResolver]
    def execute
      old_data = spinner "Reading stack #{pastel.cyan(stack_name)} from master" do
        gather_master_data(stack_name)
      end

      new_data = spinner "Parsing #{pastel.cyan(source)}" do
        loader.flat_dependencies(
          stack_name,
          variables: values_from_options
        )
      end

      changes = process_data(old_data, new_data)

      display_report(changes)

      return if dry_run?

      get_confirmation(changes)

      deployable_stacks = []
      deployable_stacks.concat run_installs(changes)
      deployable_stacks.concat run_upgrades(changes)

      run_deploys(deployable_stacks) if deploy?

      run_removes(changes.removed_stacks)

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

    # Preprocess data and return a ChangeResolver
    # @param old_data [Hash] data from master
    # @param new_data [Hash] data from files
    # @return [Kontena::Cli::Stacks::ChangeRsolver]
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
        Kontena::Stacks::ChangeResolver.new(old_set, new_set)
      end
    end

    # @param stackname [String]
    # @param data [Hash]
    # @param old_data [Hash]
    def process_stack_data(stackname, data, old_data)
      prev_env = ENV.clone
      reader = data[:loader].reader
      set_env_variables(stackname, current_grid) # set envs for execution time
      parsed_stack = reader.execute(
        values: data[:variables],
        defaults: old_data[stackname].nil? ? nil : old_data[stackname][:stack_data]['variables'],
        parent_name: data[:parent_name],
        name: data[:name]
      )
      parsed_stack["parent"] = { "name" => parsed_stack.delete("parent_name") }
      data[:stack_data] = parsed_stack
    ensure
      prev_env.each { |k, v| ENV[k] = v }
    end

    # @param changes [Kontena::Stacks::ChangeResolver]
    def display_report(changes)
      puts
      caret "Calculated changes:", dots: false

      unless changes.removed_stacks.empty?
        changes.removed_stacks.each { |stack|
          puts "  #{pastel.red('-')} #{stack}"
          changes.removed_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.red('-')} #{s}"
          end
        }
      end

      unless changes.replaced_stacks.empty?
        changes.replaced_stacks.each { |stack|
          puts "  #{pastel.yellow('-/+')} #{stack}"
          changes.upgraded_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.cyan('~')} #{s}"
          end
          changes.added_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.green('+')} #{s}"
          end
          changes.removed_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.red('-')} #{s}"
          end
        }
        changes.replaced_stacks.each do |installed_name, data|
          puts "- #{pastel.yellow(installed_name)} from #{pastel.cyan(data[:from])} to #{pastel.cyan(data[:to])}"
        end
        puts
      end

      unless changes.added_stacks.empty?
        changes.added_stacks.each { |stack|
          puts "  #{pastel.green('+')} #{stack}"
          changes.added_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.green('+')} #{s}"
          end
        }
      end

      unless changes.upgraded_stacks.empty?
        changes.upgraded_stacks.each { |stack|
          puts "  #{pastel.cyan('~')} #{stack}"
          changes.upgraded_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.cyan('~')} #{s}"
          end
          changes.added_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.green('+')} #{s}"
          end
          changes.removed_services.select { |s| s.split('/')[0] == stack }.each do |s|
            puts "    #{pastel.red('-')} #{s}"
          end
        }
      end
      puts
    end

    # requires heavier confirmation when something very dangerous is going to happen
    def get_confirmation(changes)
      unless force?
        unless changes.safe?
          puts "#{pastel.red('Warning:')} This can not be undone, data will be lost."
          confirm
        end
      end
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
      changes.added_stacks.reverse_each do |added_stack|
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
      changes.upgraded_stacks.reverse_each do |upgraded_stack|
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
