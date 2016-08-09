module Kontena
  module Util
    
    def self.included(base)
        base.extend(ClassMethods)
    end

    # @param [String] cmd
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        }
      end
      return nil
    end
    module_function(:which)

    module ClassMethods
      def experimental?
        ENV.has_key?('KONTENA_EXPERIMENTAL')
      end   
    end
    
  end
end
