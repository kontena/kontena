module Kontena::Cli::Stacks
  module YAML
    module Opto
      module Resolvers; end
      module Setters; end
    end
  end
end
require 'opto'
require_relative 'opto/vault_setter'
require_relative 'opto/vault_resolver'
require_relative 'opto/prompt_resolver'
require_relative 'opto/service_instances_resolver'
require_relative 'opto/vault_cert_prompt_resolver'
require_relative 'opto/certificates_resolver'
require_relative 'opto/service_link_resolver'
