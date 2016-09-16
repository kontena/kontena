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

    def put(key, value)
      if value.nil?
        delete(key)
      else
        find_or_create_by(key: key.to_s).update_attribute(:value, {VALUE => value})
      end
    end

    def get(key)
      item = where(key: key.to_s).first
      if item
        item.value[VALUE]
      else
        nil
      end
    end

    def delete(key)
      where(key: key.to_s).destroy
    end

    def [](key)
      get(key.to_s)
    end

    def []=(key, value)
      put(key, value)
    end

    def to_h
      {}.tap {|hash| all.each{|item| hash[item.key] = item.value[VALUE]}}
    end
  end
end
