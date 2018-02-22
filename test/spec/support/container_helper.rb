require 'json'

module ContainerHelper

  # Checks if a deployed container exists with given name
  # @param [String] name of the container to check
  def container_exist?(name)
    k = run "kontena container ls -q"
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

  # Finds containers id based on name
  # @param [String] name
  def container_id(name)
    k = run("kontena container list -q")
    k.out.match("^(.+\/#{name})")[1]
  end

  # @raise [RuntimeError]
  # @return [Hash]
  def inspect_container(container_id)
    k = run("kontena container inspect #{container_id}")
    ::JSON.parse(k.out)
  end
end
