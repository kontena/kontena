require_relative 'common'

module Kontena::Cli::Stacks
  class UpgradeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Upgrades a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    include Common::StackFileOrNameParam
    include Common::StackValuesFromOption

    option '--[no-]deploy', :flag, 'Trigger deploy after upgrade', default: true

    requires_current_master
    requires_current_master_token

    def execute
      master_data = spinner "Reading stack #{pastel.cyan(name)} metadata from Kontena Master" do |spin|
        read_stack || spin.fail!
      end

      stack = stack_from_yaml(filename, name: name, values: values, from_registry: from_registry, defaults: master_data['variables'])

      spinner "Upgrading stack #{pastel.cyan(name)}" do |spin|
        update_stack(stack) || spin.fail!
      end

      Kontena.run(['stack', 'deploy', name]) if deploy?
    end

    def update_stack(stack)
      client.put(stack_url, stack)
    end

    def stack_url
      @stack_url ||= "stacks/#{current_grid}/#{name}"
    end

    def read_stack
      client.get(stack_url)
    end
  end
end
