module Kontena
  module Cli
    unless const_defined?(:VERSION)
      require 'pathname'
      version_file = Pathname.new(__FILE__).dirname.join('../../../VERSION').realpath
      if ENV["_KONTENA_HOMEBREW"]
        head_path = version_file.to_s.split(File::SEPARATOR).detect { |component| component.start_with?('HEAD') }
        head = head_path.nil? ? nil : ".pre.#{head_path.gsub("-", '_').downcase}"
      end
      VERSION = "#{version_file.read.strip}#{head}"
    end
  end
end
