module VolumesHelpers

  def parse_volume(vol)
    elements = vol.split(':')
    if elements.size >= 2 # Bind mount or volume used
      if elements[0].start_with?('/') && elements[1] && elements[1].start_with?('/') # Bind mount
        {bind_mount: elements[0], path: elements[1], flags: elements[2..-1].join(',')}
      elsif !elements[0].start_with?('/') && elements[1].start_with?('/') # Real volume
        {volume: elements[0], path: elements[1], flags: elements[2..-1].join(',')}
      else
        raise ArgumentError, "Volume definition '#{vol}' not in right format"
      end
    elsif elements.size == 1 && elements[0].start_with?('/') # anon volume
      {bind_mount: nil, path: elements[0], flags: nil} # anon vols do not support flags
    else
      raise ArgumentError, "Volume definition '#{vol}' not in right format"
    end
  end

end
