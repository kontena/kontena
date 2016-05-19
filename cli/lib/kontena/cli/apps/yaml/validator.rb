require 'dry-validation'

module Kontena::Cli::Apps
  module YAML
    class Validator
      ##
      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      def initialize
        @yaml_schema = Dry::Validation.Schema do
          optional('image').maybe(:str?)
          optional('extends').schema do
            key('service').required(:str?)
            optional('file') { str? }
          end
          rule(image_required: ['extends', 'image']) do |extends, image|
            extends.none?.then(image.filled?)
          end
          optional('build') { str? }
          optional('dockerfile') { str? }
          optional('affinity') { array? { each { format?(/(?<=\!|\=)=/) } } }
          optional('stateful') { bool? }
          optional('cap_add') { array? | none? }
          optional('cap_drop') { array? | none? }
          optional('command') { str? | none? }
          optional('cpu_shares') { int? | none? }
          optional('mem_limit') { int? | str? }
          optional('memswap_limit') { int? | str? }
          optional('environment') { array? | type?(Hash) }
          optional('env_file') { str? | array? }
          optional('external_links') { str? }
          optional('instances') { int? }
          optional('external_links') { array? }
          optional('links') { array? }
          optional('ports') { array? }
          optional('volumes') { array? }
          optional('volumes_from') { array? }
          optional('deploy').schema do
            optional('strategy') { inclusion?(%w(ha daemon random)) }
            optional('wait_for_port') { int? }
            optional('min_health') { float? }
          end
          optional('hooks').schema do
            optional('post_start').each do
              key('name').required
              key('cmd').required
              key('instances') { int? | eql?('*') }
              optional('oneshot') { bool? }
            end
            optional('pre_build').each do
              key('cmd').required
            end
          end
          optional('log_driver') { str? }
          optional('log_opts') { type?(Hash) }
          optional('secrets').each do
            key('secret').required
            key('name').required
            key('type').required
          end
        end
      end

      ##
      # @param [Hash] yaml
      # @return [Array] validation_errors
      def validate(yaml)
        validation_errors = []
        yaml.each do |service, options|
          result = validate_service(options)
          validation_errors << { service => result.messages } if result.failure?
        end
        validation_errors
      end

      def validate_service(options)
        @yaml_schema.call(options)
      end
    end
  end
end
