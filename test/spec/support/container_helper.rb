module ContainerHelper

  # Checks if a deployed container exists with given name
  # @param [String] name of the container to check
  def container_exist?(name)
    k = run "kontena container ls"
    fail "kontena container ls command failed: #{k.out}" if k.code != 0
    k.out.include?(name)
  end

  # Waits until no container exists with the name
  # @param [String] name of the container to check
  def wait_until_container_gone(name)
    loop do
      return unless container_exist?(name)
      sleep 1
    end
  end

end