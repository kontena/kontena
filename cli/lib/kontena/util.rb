module Kontena
  module Util
    def self.included(base)
      base.extend(ClassMethods)
    end

    def symbolize_keys(obj)
      case obj
      when Hash
        obj.map { |k,v| [k.to_sym, symbolize_keys(v)] }.to_h
      when Array
        obj.map { |v| symbolize_keys(v) }
      else
        obj
      end
    end
    module_function :symbolize_keys

    def symbolize_keys!(obj)
      case obj
      when Hash
        obj.keys.each { |k| obj[k.to_sym] = symbolize_keys!(obj.delete(k)) }
      when Array
        obj.map! { |v| symbolize_keys!(v) }
      else
      end
      obj
    end
    module_function :symbolize_keys!

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

    # Compatibility between ruby_dig and Ruby 2.3. Ruby_dig returns
    # nil when trying to dig into a string, Ruby 2.3 dig raises
    # TypeError.
    #
    # @param [Hash] source_hash
    # @param [*keys] list_of_keys
    def safe_dig(hash, *keys)
      hash.dig(*keys)
    rescue TypeError
      nil
    end

    def time_ago(time)
      now = Time.now.to_i
      time = DateTime.parse(time).to_time.to_i
      diff = now - time
      if diff > 60 * 60 * 24
        "#{diff / 60 / 60 / 24} days"
      elsif diff > 60 * 60
        "#{diff / 60 / 60} hours"
      elsif diff > 60
        "#{diff / 60} minutes"
      else
        "#{diff} seconds"
      end
    end

    def longest_string_in_array(array)
      longest = 0
      array.each do |item|
        longest = item.length if item.length > longest
      end

      longest
    end

    module_function(:which)

    module ClassMethods
      def experimental?
        ENV.has_key?('KONTENA_EXPERIMENTAL')
      end
    end

  end
end
