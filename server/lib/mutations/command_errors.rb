module Mutations
  class Command
    protected

    # Add multiple errors for a key
    #
    def add_errors(key, kind, message = nil)
      raise ArgumentError.new("Invalid kind of #{kind.class}") unless kind.is_a?(Symbol)

      @errors ||= ErrorHash.new
      path = key.to_s.split(".")
      last = path.pop
      inner = path.inject(@errors) do |cur_errors,part|
        cur_errors[part.to_sym] ||= ErrorHash.new
      end
      inner[last] ||= ErrorArray.new
      inner[last] << ErrorAtom.new(key, kind, message: message)
    end

    # Add nested errors from a sub-mutation.
    #
    # @param key [String] Top-level services.asdf key
    # @param errors [ErrorHash] Sub-mutation Outcome.errors
    def add_outcome_errors(key, errors)
      raise ArgumentError.new("Invalid kind of #{kind.class}") unless errors.is_a?(ErrorHash)

      @errors ||= ErrorHash.new
      @errors.tap do |errs|
        path = key.to_s.split(".")
        last = path.pop
        inner = path.inject(errs) do |cur_errors,part|
          cur_errors[part.to_sym] ||= ErrorHash.new
        end
        inner[last] = errors
      end
    end
  end
end
