module Kontena
  module Cli
    VERSION = File.read(File.realpath(File.join(__dir__, '../../../VERSION'))).strip unless const_defined?(:VERSION)
  end
end
