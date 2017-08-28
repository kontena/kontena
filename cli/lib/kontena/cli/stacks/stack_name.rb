module Kontena::Cli::Stacks
  class StackName

    attr_reader :user, :stack, :version

    def initialize(definition = nil)
      if definition.kind_of?(Hash)
        @user = definition[:user] || definition['user']
        @stack = definition[:stack] || definition['stack']
        @version = definition[:version] || definition['version']
      elsif definition.kind_of?(String)
        parsed = parse(definition)
        @user = parsed[:user]
        @stack = parsed[:stack]
        @version = parsed[:version]
      end
    end

    def to_s
      [[user, stack].join('/'), version].join(':')
    end
    alias to_str to_s

    private

    def parse(definition)
      return {} if definition.empty?
      name, version = definition.split(':', 2)
      if name.include?('/')
        user, stack = name.split('/', 2)
      else
        user = nil
        stack = name
      end
      {
        user: user,
        stack: stack,
        version: version
      }
    end

  end
end
