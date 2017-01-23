module Kontena::Helpers
  module LauncherHelper
    include Kontena::Helpers::WaitHelper

    # @return [String]
    def container_name
      NAME
    end

    # @return [Docker::Container, nil]
    def get_container
      Docker::Container.get(container_name)
    rescue Docker::Error::NotFoundError => error
      nil
    end

    protected

    # XXX: gets stuck without the :version if there is no latest tag?

    # @param [String] image:version
    def ensure_image(image)
      return if Docker::Image.exist?(image)

      debug "ensure_image: create #{image}"

      image = Docker::Image.create('fromImage' => image)

      # XXX: doesn't the the create block until the image exists?
      #wait!("until pulled image=#{image}"){ Docker::Image.exist?(image) }
    end

    def inspect(container)
      return {
        image: container.config['Image'],
      }
    end

    def up
      ensure_image
      ensure_running
    end

    def ensure_running

    end

    def kill!(container)
      container.delete(force: true)
    end

    def launch!

    end
  end
end
