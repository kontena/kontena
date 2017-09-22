module Kontena::Cli::Stacks
  module YAML
    class RawContentLoader < StackFileLoader
      # For loading from a string directly, probably mostly useful in specs
      def self.match?(source, parent = nil)
        source.kind_of?(String) && source.count("\n") > 0 && source.include?("stack: ")
      end

      def inspect
        super.gsub(/@content=".+?[^\\]"/m, "@content=\"...\"")
      end

      def initialize(*args)
        super
        @content = source.dup
        @source = "string"
      end

      def read_content
        @content
      end

      def origin
        "string"
      end

      def registry
        "file://"
      end
    end
  end
end
