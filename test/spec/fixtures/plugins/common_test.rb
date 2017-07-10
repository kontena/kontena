require 'kontena_cli'

include Kontena::Cli::Common

spinner "test" do
  sleep 0.1
end

puts current_master
puts current_grid
puts config.servers.size
puts pastel.green('hello')
puts prompt.help_color
logger.info "hello"
raise "foo" unless respond_to?(:ask)
raise "foo" unless respond_to?(:yes?)
puts StringIO.new.inspect
