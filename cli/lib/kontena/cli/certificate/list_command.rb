require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::TableGenerator::Helper
    include Kontena::Util

    requires_current_master
    requires_current_master_token
    requires_current_grid

    SEVEN_DAYS = 7 * 24 * 60 * 60
    THREE_DAYS = 3 * 24 * 60 * 60

    def fields
      quiet? ? ['subject'] : {subject: 'subject', "expiration" => 'expires_in', auto_renewable?: 'auto_renewable'}
    end

    def certificates
      client.get("grids/#{current_grid}/certificates")['certificates']
    end

    def status_icon(expires_in)
      icon = '⊛'.freeze

      if expires_in < 0
        icon.colorize(:red)
      else
        icon.colorize(:green)
      end

    end

    def status_color(expires_in)

      if expires_in < 0
        :red
      elsif expires_in < THREE_DAYS
        :bright_yellow
      elsif expires_in < SEVEN_DAYS
        :yellow
      else
        :green
      end

    end

    def expires_in(certificate)
      valid_until = Time.parse(certificate['valid_until'])
      (valid_until - Time.now).to_i
    end

    def expires_in_human(expires_in)
      if expires_in > 0
        text = seconds_to_human(expires_in)
      else
        text = seconds_to_human(-1 * expires_in) + ' ago'
      end

      text.colorize(status_color(expires_in))
    end

    def execute
      print_table(certificates) do |certificate|
        expires_in = expires_in(certificate)
        certificate['subject'] = status_icon(expires_in) + " " + certificate['subject'] unless quiet?
        next if quiet? # No need to fiddle with colors when they will not get printed
        certificate['expires_in'] = expires_in_human(expires_in)
      end
    end

  end
end
