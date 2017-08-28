module Kontena::Cli::Stacks
  module YAML
    class FileLoader < StackFileLoader
      def self.match?(source)
        ::File.exist?(source)
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
