module Kontena
  module Cli
    unless const_defined?(:VERSION)
      require 'pathname'
      version_file = Pathname.new(__FILE__).dirname.join('../../../VERSION').realpath
      is_head = ENV["KONTENA_EXTRA_BUILDTAGS"].to_s.include?('head')
      VERSION = "#{version_file.read.strip}#{"-head" if is_head}"
    end

    unless const_defined?(:BUILD_TAGS)
      BUILD_TAGS = [ 'ruby' + RUBY_VERSION, RUBY_PLATFORM]
        .concat(ENV["KONTENA_EXTRA_BUILDTAGS"].to_s.split(','))
        .compact
        .join('+').freeze
    end
  end
end
