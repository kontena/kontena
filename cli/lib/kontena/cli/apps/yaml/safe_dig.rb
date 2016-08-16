module SafeDig
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
end
