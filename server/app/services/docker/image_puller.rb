module Docker
  class ImagePuller

    PULL_TIMEOUT = 600

    ##
    # @param [HostNode] node
    # @param [Hash] creds
    def initialize(node, creds = nil)
      @node = node
      @creds = creds
    end

    ##
    # @param [String] image_name
    # @return [Image]
    def pull_image(image_name)
      begin
        client(PULL_TIMEOUT).request('/images/create', {fromImage: image_name}, @creds)
      rescue RpcClient::TimeoutError => exc
        raise "Image pull timed out: #{image_name}"
      end

      image = Image.find_by(name: image_name)
      unless image
        image = Image.create!(name: image_name)
      end
      @node.images << image
      json = client.request('/images/show', image_name)
      if json['Config']['ExposedPorts']
        image.exposed_ports = json['Config']['ExposedPorts'].map{|key, _|
          port, protocol = key.split('/'); {'port' => port, 'protocol' => protocol}
        }
      end
      image.image_id = json['Id']
      image.size = json['Size']
      image.save

      image
    end

    private

    ##
    # @param [Integer] timeout
    # @return [RpcClient]
    def client(timeout = 300)
      @node.rpc_client(timeout)
    end

    ##
    # @param [String] image
    # @return [Boolean]
    def image_exists?(image)
      image = client.request('/images/show', image) rescue nil
      !image.nil?
    end
  end
end
