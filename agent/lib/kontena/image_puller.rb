require 'docker'
require_relative 'logging'

module Kontena
  class ImagePuller
    include Kontena::Logging

    # @param [String] image
    # @param [String] deploy_rev
    # @param [Hash, NilClass] creds
    def ensure_image(image, deploy_rev, creds = nil)
      self.class.mutex.synchronize do
        unless fresh_pull?("#{image}:#{deploy_rev}")
          self.pull_image(image, deploy_rev, creds)
        end
      end
    end

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
          raise exc
        else
          info "image pull failed, using local image: #{image}"
        end
      end
    end

    # @param [String] image
    # @return [Boolean]
    def fresh_pull?(image)
      return false unless self.class.image_cache[image]
      self.class.image_cache[image] >= (Time.now.utc - 600)
    end

    def image_exists?(image)
      image = Docker::Image.get(image) rescue nil
      !image.nil?
    end

    # @param [String] image
    def update_image_cache(image)
      self.class.image_cache[image] = Time.now.utc
    end

    # @return [Hash]
    def self.image_cache
      @image_cache ||= {}
    end

    # @return [Mutex]
    def self.mutex
      @mutex ||= Mutex.new
    end
  end
end
