require 'fileutils'
require 'erb'

module Kontena
  module Machine
    module CloudConfig
      class NodeGenerator

        # @param [Hash] opts
        def generate(opts)
          user_data(opts)
        end

        # @param [Hash] vars
        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        # @param [String] template
        # @param [Hash] vars
        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end
