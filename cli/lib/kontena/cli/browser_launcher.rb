require 'kontena/util'

module Kontena
  module Cli
    class BrowserLauncher
      def self.open(url)
        Kontena::Cli::BrowserLauncher.new(url).launch
      end

      attr_reader :url

      def initialize(url)
        @url = url
      end

      def launch
        system(*command)
      end

      def command
        if Kontena.on_windows?
          ['start', url]
        elsif RUBY_PLATFORM =~ /darwin/
          ["open", url]
        elsif Kontena.browserless?
          raise RuntimeError, "Environment variable DISPLAY not set, assuming non-desktop session, unable to open browser. Try using '--remote' option."
        else
          [detect_unixlike_command, url]
        end
      end

      def detect_unixlike_command
        cmd = %w(
          xdg-open
          sensible-browser
          x-www-browser
        ).find { |c| !which(c).nil? }
        if cmd.nil?
          if ENV['BROWSER']
            cmd = which(ENV['BROWSER'])
            return cmd unless cmd.nil?
          end
          raise RuntimeError, "Unable to launch a local browser. Try installing xdg-utils or sensible-utils package, setting BROWSER environment variable or using the --remote option"
        end
        cmd
      end

      def which(cmd)
        Kontena::Util.which(cmd)
      end
    end
  end
end
