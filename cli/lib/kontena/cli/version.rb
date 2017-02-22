module Kontena
  module Cli
    unless const_defined?(:VERSION)
      VERSION = File.read(File.realpath(File.join(__dir__, '../../../VERSION'))).strip + ENV["_HOMEBREW_HEAD"].to_s
    end
  end
end
