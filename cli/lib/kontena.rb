require_relative 'kontena/cli/configuration'
require_relative 'kontena/client'
require_relative 'kontena/master_client'
require_relative 'kontena/account_client'
require_relative 'kontena/cli'

module Kontena
  def self.config
    @config ||= Kontena::Cli::Configuration.new
  end

  def self.master_client
    @client ||= Kontena::Cli::MasterClient.new(config.current_master)
  end

  def self.account_client
    @client ||= Kontena::Cli::AccountClient.new(config.current_account)
  end
end
