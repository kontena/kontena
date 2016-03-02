module Kontena::Workers
  class ImageCleanupWorker
    include Celluloid
    include Kontena::Logging

    CLEANUP_INTERVAL = 60
    CLEANUP_DELAY = (60*60)

    ##
    # @param [Boolean] autostart
    def initialize(autostart = true)
      info 'initialized'
      async.start if autostart
    end

    def start
      loop do
        sleep CLEANUP_INTERVAL
        cleanup_images
      end
    end

    def cleanup_images
      images = Docker::Image.all.map{|i| [i.id, i]}.to_h
      reject_used_images(images)
      sleep CLEANUP_DELAY
      reject_used_images(images)
      images.values.each do |image|
        begin
          image.remove
          info "Removed image: #{image.id}"
        rescue
          error "Failed to remove image: #{image.id} (#{image.info['RepoTags'].join(',')})"
        end
      end
    end

    # @param [Hash] images
    def reject_used_images(image_map)
      Docker::Container.all(all: true).each do |container|
        image_map.delete(container.info['ImageID'])
      end
    end
  end
end
