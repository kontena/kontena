module VolumesHelpers

  def build_service_volume(vol)
    elements = vol.split(':')
    if elements[0].start_with?('/') && elements[1] && elements[1].start_with?('/') # Bind mount
      ServiceVolume.new(bind_mount: elements[0], path: elements[1], flags: elements[2..-1].join(':'))
    elsif !elements[0].start_with?('/') && elements[1].start_with?('/') # Real volume
      name = elements[0]
      volume = Volume.find_by!(name: name)
      ServiceVolume.new(volume: volume, path: elements[1], flags: elements[2..-1].join(':'))
    elsif elements[0].start_with?('/') && elements.size == 1 # anon volume
      ServiceVolume.new(bind_mount: nil, path: elements[0], flags: nil) # anon vols do not support flags
    end
  end

end
