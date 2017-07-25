require_relative '../helpers/image_helper'
require_relative '../helpers/iface_helper'

module Kontena::NetworkAdapters
  class WeaveExecutor
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::ImageHelper

    def initialize(autostart = true)
      @images_exist = false
      info 'initialized'
      async.ensure_images if autostart
    end

    # @param [Array<String>] cmd
    # @yield [line] Each line of output
    def execute(cmd, &block)
      begin
        container = Docker::Container.create(
          'Image' => weave_exec_image,
          'Cmd' => cmd,
          'Volumes' => {
            '/var/run/docker.sock' => {},
            '/host' => {}
          },
          'Labels' => {
            'io.kontena.container.skip_logs' => '1'
          },
          'Env' => [
            'HOST_ROOT=/host',
            "VERSION=#{weave_version}",
            "WEAVE_DEBUG=#{ENV['WEAVE_DEBUG']}",
          ],
          'HostConfig' => {
            'Privileged' => true,
            'NetworkMode' => 'host',
            'PidMode' => 'host',
            'Binds' => [
              '/var/run/docker.sock:/var/run/docker.sock',
              '/:/host'
            ]
          }
        )
        retries = 0
        response = {}
        begin
          response = container.tap(&:start).wait
        rescue Docker::Error::NotFoundError => exc
          error exc.message
          return false
        rescue => exc
          retries += 1
          error exc.message
          sleep 0.5
          retry if retries < 10

          error exc.message
          return false
        end

        status_code = response["StatusCode"]
        output = container.streaming_logs(stdout: true, stderr: true)
        command = censor_password(cmd)
        if status_code != 0
          error "weaveexec exit #{status_code}: #{command}\n#{output}"
          return false
        elsif block
          debug "weaveexec stream: #{command}"
          output.each_line &block
          return true
        else
          debug "weaveexec ok: #{command}\n#{output}"
          return true
        end
      ensure
        container.delete(force: true, v: true) if container
      end
    end

    # List network information for container(s)
    #
    # @param [Array<String>] what for given Docker IDs, 'weave:expose', or all
    # @yield [name, mac, *cidrs]
    # @yieldparam [Array<String>] cidrs
    def ps(*what)
      self.execute(['--local', 'ps', *what]) do |line|
        yield *line.split()
      end
    end

    # Configure given address on host weave bridge.
    # Also configures iptables rules for the subnet
    #
    # @param [String] cidr '10.81.0.X/16' host node overlay_cidr
    def expose(cidr)
      self.execute(['--local', 'expose', "ip:#{cidr}"])
    end

    # De-configure given address on host weave bridge.
    # Aslo removes iptables rules for the subnet
    #
    # @param [String] cidr '10.81.0.X/16' host node overlay_cidr
    def hide(cidr)
      self.execute(['--local', 'hide', cidr])
    end

    # Configure ethwe interface with cidr for given container
    #
    # @param [String] id Docker ID
    # @param [String] cidr Overlay '10.81.X.Y/16' CIDR
    def attach(id, cidr)
      self.execute(['--local', 'attach', cidr, '--rewrite-hosts', id])
    end

    # De-configure ethwe interface with cidr for given container
    #
    # @param [String] id Docker ID
    # @param [String] cidr Overlay '10.81.X.Y/16' CIDR
    def detach(id, cidr)
      self.execute(['--local', 'detach', cidr, id])
    end

    private

    def weave_exec_image
      "#{Weave::WEAVEEXEC_IMAGE}:#{Weave::WEAVE_VERSION}"
    end

    def weave_version
      Weave::WEAVE_VERSION
    end

    def ensure_images
      pull_image(weave_exec_image)
      @images_exist = true
    end

    # @param [Array<String>] cmd
    def censor_password(command)
      if command.include?('--password')
        cmd = command.dup
        passwd_index = cmd.index('--password')
        cmd[passwd_index + 1] = '<redacted>'

        cmd
      else
        command
      end
    end

  end
end
