class KontenaJsonSerializer < JsonSerializer

  def decorate
    return nil unless object

    if object.is_a?(Array)
      to_arry
    else
      to_hash
    end
  end

  def created_at
    object.created_at.try(:iso8601)
  end

  def updated_at
    object.created_at.try(:iso8601)
  end

  def to_hash
    super
  end
end
