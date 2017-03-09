module VolumesHelpers

  def parse_volume(vol)
    elements = vol.split(':')
    if elements[0].start_with?('/') && elements[1] && elements[1].start_with?('/') # Bind mount
      {bind_mount: elements[0], path: elements[1], flags: elements[2..-1].join(':')}
    elsif !elements[0].start_with?('/') && elements[1].start_with?('/') # Real volume
      {volume: elements[0], path: elements[1], flags: elements[2..-1].join(':')}
    elsif elements[0].start_with?('/') && elements.size == 1 # anon volume
      {bind_mount: nil, path: elements[0], flags: nil} # anon vols do not support flags
    end
  end

end
