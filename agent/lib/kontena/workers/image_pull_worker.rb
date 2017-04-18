
module Kontena::Workers
  class ImagePullWorker
    include Celluloid
    include Kontena::Logging

    attr_reader :image_cache

    def initialize
      @image_cache = {}
    end

    # @param [String] image
    # @param [String] deploy_rev
    # @param [Hash, NilClass] creds
    def ensure_image(image, deploy_rev, creds = nil)
      unless fresh_pull?("#{image}:#{deploy_rev}")
        pull_image(image, deploy_rev, creds)
      end
    end

    # @param [String] image
    # @param [String] deploy_rev
    # @param [Hash, NilClass] creds
    def pull_image(image, deploy_rev, creds)
      if creds.nil?
        info "pulling image: #{image}"
      else
        info "pulling image with credentials: #{image}"
      end
      update_image_cache("#{image}:#{deploy_rev}")
      retries = 0
      begin
        Docker::Image.create({'fromImage' => image}, creds)
        info "pulled image: #{image}"
      rescue => exc
        retries += 1
        if retries < 10
          warn "image pull failed: #{exc.message}. Retrying still for #{10 - retries} times."
          sleep 0.1
          retry
        end
        unless image_exists?(image)
          abort exc
        else
          info "image pull failed, using local image: #{image}"
        end
      end
    end

    # @param [String] image
    # @return [Boolean]
    def fresh_pull?(image)
      return false unless image_cache[image]
      image_cache[image] >= (Time.now.utc - 600)
    end

    # @param [String] image
    # @return [Boolean]
    def image_exists?(image)
      image = Docker::Image.get(image) rescue nil
      !image.nil?
    end

    # @param [String] image
    def update_image_cache(image)
      image_cache[image] = Time.now.utc
    end
  end
end
