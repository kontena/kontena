require 'yaml'
require_relative 'common'

module Kontena::Cli::Apps
  class DockerfileGenerator
    include Common

    def generate(base_image)

      dockerfile = File.new('Dockerfile', 'w')
      dockerfile.puts "FROM #{base_image}"
      dockerfile.puts 'CMD ["/start", "web"]'
      dockerfile.close
    end
  end
end