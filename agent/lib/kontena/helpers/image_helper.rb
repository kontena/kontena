module Kontena
  module Helpers
    module ImageHelper

      # @param [String] image
      def pull_image(image)
        if Docker::Image.exist?(image)
          return
        end
        Docker::Image.create('fromImage' => image)
        sleep 1 until Docker::Image.exist?(image)
      end

    end
  end
end
