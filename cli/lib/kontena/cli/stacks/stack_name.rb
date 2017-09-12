require 'semantic'

module Kontena::Cli::Stacks
  class StackName
    # A class for parsing stack name strings, such as kontena/foo:1.0.0

    attr_reader :user, :stack, :version

    # @param definition [String] such as kontena/foo:1.0.0
    # @param version [String] set version separately
    # @return [StackName]
    # @example
    #   name = StackName.new('kontena/foo:0.1.0')
    #   name.user => 'kontena'
    #   name.stack => 'foo'
    #   name.version => '0.1.0'
    #   name.stack_name => 'kontena/foo'
    #   name.to_s => 'kontena/foo:0.1.0
    def initialize(definition = nil, version = nil)
      if definition.kind_of?(Hash)
        @user = definition[:user] || definition['user']
        @stack = definition[:stack] || definition['stack']
        @version = definition[:version] || definition['version'] || version
      elsif definition.kind_of?(String)
        parsed = parse(definition)
        @user = parsed[:user]
        @stack = parsed[:stack]
        @version = parsed[:version] || version
      end
    end

    # Stack name without version
    # @return [String] example: kontena/foo
    def stack_name
      [user, stack].compact.join('/')
    end

    # Full stack name including version if present
    # @return [String] example: kontena/foo:0.1.0
    def to_s
      version ? "#{stack_name}:#{version}" : stack_name
    end
    alias to_str to_s

    # True when version is a prerelease
    # @return [NilClass,TrueClass,FalseClass] nil when no version, true when prerelease, false when not.
    def pre?
      return nil if version.nil?
      !Semantic::Version.new(version).pre.nil?
    end

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
