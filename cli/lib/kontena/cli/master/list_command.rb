module Kontena::Cli::Master
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper

    def fields
      @fields ||= quiet? ? %w(name) : %w(name url)
    end

    def current_master_name
      @current_master_name ||= current_master.nil? ? nil : current_master.name
    end

    def mark_if_current(row)
      unless quiet?
        row.name.to_s.insert(0, pastel.yellow('* ')) if row.name == current_master_name
      end
    end

    def execute
      print_table(config.servers, fields, &method(:mark_if_current))
    end
  end
end
