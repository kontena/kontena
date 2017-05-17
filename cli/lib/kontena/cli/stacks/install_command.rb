require_relative 'common'

module Kontena::Cli::Stacks
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Installs a stack to a grid on Kontena Master"

    include Common::StackFileOrNameParam

    include Common::StackNameOption
    option '--[no-]deploy', :flag, 'Trigger deploy after installation', default: true

    include Common::StackValuesToOption
    include Common::StackValuesFromOption

    requires_current_master
    requires_current_master_token

    def execute
      stack = stack_read_and_dump(filename, name: name, values: values)

      stack['name'] = name if name
      spinner "Creating stack #{pastel.cyan(stack['name'])} " do
        create_stack(stack)
      end
      display_post_install_messages(stack)
      Kontena.run("stack deploy #{stack['name']}") if deploy?
    end

    def display_post_install_messages(stack)
      Array(stack[:services] || stack['services']).each do |service|
        next unless service['hooks']
        next unless service['hooks']['post_install']
        service['hooks']['post_install'].each do |pi|
          puts "Service #{pastel.cyan(service['name'])} post install message:"
          puts
          puts pi['message'] if pi['message']
        end
      end
    end

    def create_stack(stack)
      client.post("grids/#{current_grid}/stacks", stack)
    end
  end
end
