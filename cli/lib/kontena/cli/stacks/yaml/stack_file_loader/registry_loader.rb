module Kontena::Cli::Stacks
  module YAML
    class RegistryLoader < StackFileLoader
      def self.match?(source, parent = nil)
        source =~ /\A[a-zA-Z0-9\_\.\-]+\/[a-zA-Z0-9\_\.\-]+(?::.*)?\z/ && !FileLoader.match?(source, parent)
      end

      def read_content
        Kontena::StacksCache.pull(source)
      end

      def origin
        "registry"
      end

      def registry
        account = Kontena::Cli::Config.current_account
        raise "Current account not set" if account.nil?
        account.stacks_url
      end
    end
  end
end

