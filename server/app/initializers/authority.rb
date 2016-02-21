require 'authority'

Authority.configure do |config|
  config.abilities =  {
    :create => 'creatable',
    :read   => 'readable',
    :update => 'updatable',
    :delete => 'deletable',
    :deploy => 'deployable',
    :assign => 'assignable',
    :unassign => 'unassignable'
  }
end

require_relative '../authorizers/application_authorizer'
