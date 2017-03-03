module Kontena::Cli
  class SubcommandLoader
    attr_reader :path, :class_definition

    # Create a subcommand loader instance
    #
    # @param [String] path path to command definition
    # @param [Symbol|String|Array] class_definition example: :Kontena, :Cli, :Master, :UseCommand.
    #   if left empty, tries to guess from path: 'master/use_command' will become :Master, :UseCommand
    def initialize(path, *class_definition)
      @path = path
      if class_definition.empty?
        @class_definition = path.gsub(/.*\/cli\//, '').split('/').map do |path_part|
          path_part.split('_').map{ |e| e.capitalize }.join
        end.map(&:to_sym)
      elsif class_definition.first.kind_of?(String) && class_definition.size == 1
        @class_definition = class_definition.split('::').map(&:to_sym)
      else
        @class_definition = class_definition.map(&:to_sym)
      end
    end

    def get_class
      retried = false
      begin
        definition = class_definition.dup
        base = Object.const_get(definition.shift)
        if definition.empty?
          subcommand_class = base
        else
          subcommand_class = class_definition.inject(base) { |new_base, part| new_base.const_get(part) }
        end
      rescue
        unless retried
          @class_definition.delete_if {|v| v == :Kontena || v == :Cli}
          @class_definition = [:Kontena, :Cli] + @class_definition
          retried = true
          retry
        end
        raise ArgumentError, "Can not figure out command class name: #{@class_definition.inspect} (#{@path.inspect})"
      end

      subcommand_class
    end

    def klass
      return @subcommand_class if @subcommand_class
      path = @path + '.rb' unless @path.end_with?('.rb')
      if File.exist?(path)
        require(path)
      elsif File.exist?(Kontena.cli_root(path))
        require(Kontena.cli_root(path))
      else
        raise ArgumentError, "Can not load #{path} or #{Kontena.cli_root(path)}"
      end
      @subcommand_class = get_class
    end

    def new(*args)
      klass.new(*args)
    end

    def method_missing(meth, *args)
      klass.send(meth, *args)
    end

    def respond_to_missing?(meth)
      klass.respond_to?(meth)
    end

    def const_get(const)
      klass.const_get(const)
    end

    def const_defined?(const)
      klass.const_defined?(const)
    end

    alias_method :class, :klass
  end
end
