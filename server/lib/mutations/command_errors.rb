require 'mutations'

module Mutations
  class Command
    protected

    # Add error for a key
    #
    # @param key [Symbol] :foo
    # @param key [String] 'foo.bar'
    # @param error [Symbol] :not_found
    # @param error [Mutations:ErrorAtom, Mutations::ErrorArray, Mutations::ErrorHash]
    def add_error(key, error, message = nil)
      if error.is_a? Symbol
        error = ErrorAtom.new(key, error, message: message)
      elsif error.is_a?(Mutations::ErrorAtom) || error.is_a?(Mutations::ErrorArray) || error.is_a?(Mutations::ErrorHash)

      else
        raise ArgumentError.new("Invalid error of kind #{error.class}")
      end

      @errors ||= ErrorHash.new
      @errors.tap do |errs|
        path = key.to_s.split(".")
        last = path.pop
        inner = path.inject(errs) do |cur_errors,part|
          cur_errors[part.to_sym] ||= ErrorHash.new
        end
        inner[last] = error
      end
    end

    def validate_each(key)
      return unless @inputs[key]
      
      errors = ErrorArray.new
      @inputs[key].each do |item|
        kind, message = yield item

        errors << ErrorAtom.new(key, kind, message: message) if kind
      end
      if errors.any?
        add_error(key, errors)
      end
    end
  end
end
