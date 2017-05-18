module MutationsHelpers
  # Validate an array field using a block
  #
  # array :foo do
  #   string
  # end
  #
  # validate_each :foo do |foo|
  #   if already_exists(foo)
  #     [:exists, "#{foo} already exists"]
  #   else
  #     nil
  #   end
  # end
  #
  # @param key [Symbol] input field name to validate
  # @yield [item] Validate each item
  # @yieldparam item [Object] Array field item
  # @yieldreturn [Nil, Symbol, Array<(Symbol)>, Array<(Symbol, String)>] optional validation error
  def validate_each(key)
    return unless @inputs[key]

    errors = Mutations::ErrorArray.new
    @inputs[key].each do |item|
      kind, message = yield item

      errors << Mutations::ErrorAtom.new(key, kind, message: message) if kind
    end
    if errors.any?
      add_error(key, errors)
    end
  end
end
