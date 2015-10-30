require 'docker'

module Kontena
  class ImagePuller

    # @param [String] image
    # @param [Hash, NilClass] creds
    def ensure_image(image, creds = nil)
      unless fresh_pull?(image)
        update_image_cache(image)
        retries = 0
        begin
          Docker::Image.create({'fromImage' => image}, creds)
        rescue => exc
          retries += 1
          if retries < 10
            sleep 0.1
            retry
          end
          raise exc
        end
      end
    end

    # @param [String] image
    # @return [Boolean]
    def fresh_pull?(image)
      return false unless self.class.image_cache[image]
      self.class.image_cache[image] >= (Time.now.utc - 60)
    end

    # @param [String] image
    def update_image_cache(image)
      self.class.image_cache[image] = Time.now.utc
    end

    # @return [Hash]
    def self.image_cache
      @image_cache ||= {}
    end
  end
end
