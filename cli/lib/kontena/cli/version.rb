module Kontena
  module Cli
    VERSION = File.read(File.realpath(File.join(__dir__, '../../../VERSION'))).strip
  end
end
