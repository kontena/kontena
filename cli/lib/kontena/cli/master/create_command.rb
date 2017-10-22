module Kontena::Cli::Master
  class CreateCommand < Kontena::Command

    callback_matcher :master, :create_with_plugin_select

    def subcommand_tree(command = nil)
      command ||= Kontena::MainCommand

      real_command = command.respond_to?(:subcommand_class) ? command.subcommand_class : command

      tree = {}
      real_command.recognised_subcommands.each do |sub_command|
        sub_command.names.each do |command_name|
          if sub_command.subcommand_class.has_subcommands?
            tree[command_name] = subcommand_tree(sub_command)
          else
            tree[command_name] = sub_command.subcommand_class
          end
        end
      end
      tree
    end

    def master_create_subcommands(tree)
      creators = []
      tree.each do |k,cmd|
        if cmd.kind_of?(Hash)
          creators += master_create_subcommands(cmd)
        elsif cmd.respond_to?(:callback_matcher) && cmd.callback_matcher == [:master, :create]
          creators << cmd
        end
      end
      creators
    end

    def execute

      require 'shellwords'

      tree = master_create_subcommands(subcommand_tree)

      if tree.empty?
        exit_with_error "Install platform plugins first, use: kontena plugin"
      end
      cmd_class = prompt.select("Choose target platform") do |menu|
        tree.each do |cmd_class|
          plugin_name = cmd_class.to_s[/Plugin::(.+?)::/, 1]
          next unless plugin_name
          menu.choice plugin_name, cmd_class
        end
      end
      skip_options = ['--no-prompt', '--silent', '--help', '--version']
      options = []
      cmd_class.recognised_options.each do |option|
        next if option.switches.any?{ |sw| skip_options.include?(sw) }
        if option.type == :flag
          answer = prompt.yes?(option.description)
          if answer
            options << option.switches.first
          end
        else
          answer = prompt.ask("#{option.description}: ", required: option.required?, default: option.default_value)
          if answer
            options << "#{option.switches.first} #{answer.shellescape}"
          end
        end
      end
      cmd = [cmd_class.to_s[/Plugin::(.+?)::/, 1].downcase, 'master', 'create'] + options
      Kontena.run!(cmd)
    end
  end

end
