require 'symmetric-encryption'

class Configuration
  include Mongoid::Document

  field :key, type: String
  field :value, type: Hash, default: {}
  index({ 'key' => 1 }, { unique: true })

  VALUE = 'v'.freeze

  class << self
    def seed(defaults_file)
      if File.exist?(defaults_file) && File.readable?(defaults_file)
        defaults = YAML.load(ERB.new(File.read(defaults_file)).result)[ENV['RACK_ENV']] || {}
        defaults.each do |key, value|
          if get(key).nil?
            put(key, value)
          end
        end
      else
        debug "Configuration defaults #{defaults_file} not available"
      end
    end

    def should_encrypt?(key)
      key.to_s.end_with?('_secret') || key.to_s.eql?('server.salt')
    end

    def encrypt(key, value)
      return value unless should_encrypt?(key)
      SymmetricEncryption.encrypt(value, true)
    end

    def decrypt(key, value)
      return value unless should_encrypt?(key)
      SymmetricEncryption.decrypt(value)
    end

    def decrypt_all
      Hash[*all.flat_map{|item| [item.key, decrypt(item.key, item.value[VALUE])]}]
    end

    def decrypt_where(*args)
      Hash[*where(*args).flat_map{|item| [item.key, decrypt(item.key, item.value[VALUE])]}]
    end

    def put(key, value)
      if value.nil?
        delete(key)
      else
        where(key: key).find_one_and_update({key: key, value: { VALUE => encrypt(key, value) }}, {upsert: true})
      end
    end

    def get(key)
      item = where(key: key.to_s).first
      if item
        decrypt(key, item.value[VALUE])
      else
        nil
      end
    end

    def delete(key)
      where(key: key.to_s).destroy
    end

    def increment(key)
      put(key, get(key.to_s).to_i + 1)
    end

    def decrement(key)
      put(key, get(key.to_s).to_i - 1)
    end

    def [](key)
      get(key.to_s)
    end

    def []=(key, value)
      put(key, value)
    end

    def to_h
      {}.tap {|hash| all.each{|item| hash[item.key] = decrypt(item.key, item.value[VALUE])}}
    end
  end
end
