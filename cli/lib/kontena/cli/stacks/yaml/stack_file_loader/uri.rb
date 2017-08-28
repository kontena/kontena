module Kontena::Cli::Stacks
  module YAML
    class UriLoader < StackFileLoader
      def self.match?(source)
        source.include?('://') && !::File.exist?(source)
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
