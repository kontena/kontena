begin
  require "aws-sdk"
rescue LoadError
  puts "It seems that you don't have gem for AWS API installed."
  puts "Install it using: gem install aws-sdk"
  exit 1
end

require_relative 'random_name'
require_relative 'cert_helper'
require_relative 'aws/master_provisioner'
require_relative 'aws/node_provisioner'
require_relative 'aws/node_destroyer'
