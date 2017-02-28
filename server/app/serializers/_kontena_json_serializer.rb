class KontenaJsonSerializer < JsonSerializer

  def decorate
    return nil unless object

    if object.is_a?(Array)
      to_arry
    else
      to_hash
    end
  end
end
