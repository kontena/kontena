module Kontena::Cli::Apps::YAML
 module Validations

   def append_common_validations(base)
     base.optional('image').maybe(:str?)

     base.optional('extends').schema do
       required('service').filled(:str?)
       optional('file').value(:str?)
     end

     base.optional('stateful') { bool? }
     base.optional('affinity') { array? { each { format?(/(?<=\!|\=)=/) } } }
     base.optional('cap_add') { array? | none? }
     base.optional('cap_drop') { array? | none? }
     base.optional('command') { str? | none? }
     base.optional('cpu_shares') { int? | none? }
     base.optional('external_links') { array? }
     base.optional('mem_limit') { int? | str? }
     base.optional('memswap_limit') { int? | str? }
     base.optional('environment') { array? | type?(Hash) }
     base.optional('env_file') { str? | array? }
     base.optional('instances') { int? }
     base.optional('links') { array? | empty? }
     base.optional('ports') { array? }
     base.optional('volumes') { array? }
     base.optional('volumes_from') { array? }

     base.optional('deploy').schema do
       optional('strategy').value(included_in?: %w(ha daemon random))
       optional('wait_for_port') { int? }
       optional('min_health') { float? }
       optional('interval') { format?(/^\d+(min|h|d|)$/) }
     end

     base.optional('hooks').schema do
       optional('post_start').each do
         required('name').filled
         required('cmd').filled
         required('instances') { int? | eql?('*') }
         optional('oneshot') { bool? }
       end

       optional('pre_build').each do
         required('cmd').filled
       end
     end

     base.optional('secrets').each do
       required('secret').filled
       required('name').filled
       required('type').filled
     end
     base.optional('health_check').schema do
      key('protocol') { format?(/^(http|tcp)$/) }
      key('port') { int? }
      optional('uri') { format?(/\/[\S]*/) }
      optional('timeout') { int? }
      optional('interval') { int? }
      optional('initial_delay') { int? }
     end
   end

   ##
   # @param [Hash] service_config
   def validate_options(service_config)
     @yaml_schema.call(service_config)
   end

   ##
   # @param [Hash] service_config
   # @return [Array<String>] errors
   def validate_keys(service_config)
     errors = {}
     service_config.keys.each do |key|
       error = validate_required(key)
       errors[key] = error if error
     end
     errors
   end

   ##
   # @param [String] key
   def validate_required(key)
     if self.class::UNSUPPORTED_KEYS.include?(key)
       ['unsupported option']
     elsif !self.class::VALID_KEYS.include?(key)
       ['invalid option']
     else
       nil
     end
   end
 end
end
