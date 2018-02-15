module Kontena::Cli::Stacks::YAML::Opto::Resolvers
  class Certificates < ::Opto::Resolver
    include Kontena::Cli::Common

    def resolve
      return nil unless current_master && current_grid
      message = hint || 'Select SSL certificates'
      certificates = get_certificates
      if certificates.size > 0
        prompt.multi_select(message) do |menu|
          menu.default(*default_indexes(certificates)) if option.default
          certificates.each do |s|
            menu.choice s['subject']
          end
        end
      end
    end

    # @return [Array<Hash>] certificates
    def get_certificates
      client.get("grids/#{current_grid}/certificates")['certificates']
    rescue
      []
    end

    # @param certificates [Array<Hash>]
    # @return [Array<Integer>]
    def default_indexes(certificates)
      indexes = []
      option.default.to_a.each do |subject|
        index = certificates.index { |s| s['subject'] == subject }
        indexes << index.to_i + 1 if index
      end
      indexes
    end
  end
end
