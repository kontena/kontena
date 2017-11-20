require 'kontena_cli'

puts Kontena::Client.new('https://example.com').host
