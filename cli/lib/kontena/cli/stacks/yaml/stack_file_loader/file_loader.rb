require 'pathname'

module Kontena::Cli::Stacks
  module YAML
    class FileLoader < StackFileLoader
      def self.match?(source, parent = nil)
        ::File.exist?(with_context(source, parent))
      end

      def self.is_file?(parent)
        parent.is_a?(FileLoader)
      end

      def self.with_context(source, parent = nil)
        if is_file?(parent)
          File.join(File.dirname(parent.source),  source)
        else
          File.absolute_path(source)
        end
      end

      def initialize(*args)
        super
        @source = self.class.with_context(@source, @parent)
      end

      def read_content
        ::File.read(source)
      end

      def origin
        "file"
      end

      def registry
        "file://"
      end

    end
  end
end
