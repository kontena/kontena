module Kontena::Cli
  class SubcommandLoader
    attr_reader :path

    # Create a subcommand loader instance
    #
    # @param [String] path path to command definition
    def initialize(path)
      @path = path
    end

    # Takes something like /foo/bar/cli/master/foo_coimmand and returns [:Master, :FooCommand]
    #
    # @param path [String]
    # @return [Array<Symbol>]
    def symbolize_path(path)
      path.gsub(/.*\/cli\//, '').split('/').map do |path_part|
        path_part.split('_').map{ |e| e.capitalize }.join
      end.map(&:to_sym)
    end

    # Takes an array such as [:Foo] or [:Cli, :Foo] and returns [:Kontena, :Cli, :Foo]
    def prepend_kontena_cli(tree)
      [:Kontena, :Cli] + (tree - [:Cli])
    end

    # Takes an array such as [:Master, :FooCommand] and returns Master::FooCommand
    #
    # @param tree [Array<Symbol]
    # @return [Class]
    def const_get_tree(tree)
      if tree.size == 1
        Object.const_get(tree.first)
      else
        tree[1..-1].inject(Object.const_get(tree.first)) { |new_base, part| new_base.const_get(part) }
      end
    rescue
      raise ArgumentError, "Can't figure out command class name from path #{path} - tried #{tree}"
    end

    # Tries to require a file, returns false instead of raising LoadError unless succesful
    #
    # @param path [String]
    # @return [TrueClass,FalseClass]
    def safe_require(path)
      require path
      true
    rescue LoadError
      false
    end

    def klass
      return @subcommand_class if @subcommand_class
      unless safe_require(path) || safe_require(Kontena.cli_root(path))
        raise RuntimeError, "Can't load #{path} or #{Kontena.cli_root(path)}"
      end
      @subcommand_class = const_get_tree(prepend_kontena_cli(symbolize_path(path)))
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
