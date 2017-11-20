module Kontena::Cli::Stacks
  module YAML
    class UriLoader < StackFileLoader
      def self.match?(source, parent = nil)
        source.include?('://') && !FileLoader.match?(source, parent)
      end

      def read_content
        require 'open-uri'
        stream = open(source)
        stream.read
      end

      def origin
        "uri"
      end

      def registry
        "file://"
      end
    end
  end
end
