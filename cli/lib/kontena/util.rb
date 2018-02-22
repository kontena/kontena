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

    def stringify_keys(obj)
      case obj
      when Hash
        obj.map { |k,v| [k.to_s, stringify_keys(v)] }.to_h
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
    module_function :stringify_keys

    def stringify_keys!(obj)
      case obj
      when Hash
        obj.keys.each { |k| obj[k.to_s] = stringify_keys!(obj.delete(k)) }
      when Array
        obj.map! { |v| stringify_keys!(v) }
      else
      end
      obj
    end
    module_function :stringify_keys!

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
      time = time.kind_of?(Integer) ? time : DateTime.parse(time).to_time.to_i
      diff = now - time
      seconds_to_human(diff) + ' ago'
    end

    def time_until(seconds)
      'in ' + seconds_to_human(seconds)
    end

    def seconds_to_human(seconds)
      if seconds > 60 * 60 * 24
        result = "#{seconds / 60 / 60 / 24} days"
      elsif seconds > 60 * 60
        result = "#{seconds / 60 / 60} hours"
      elsif seconds > 60
        result = "#{seconds / 60} minutes"
      else
        result = "#{seconds} seconds"
      end
      result.start_with?('1 ') ? result[0..-2] : result
    end

    def longest_string_in_array(array)
      array.max_by(&:length).length
    end

    module_function(:which)

    module ClassMethods
      def experimental?
        ENV.has_key?('KONTENA_EXPERIMENTAL')
      end
    end

  end
end
