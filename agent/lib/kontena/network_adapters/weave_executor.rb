require_relative '../logging'
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
    def execute(cmd)
      sleep 0.5 until @images_exist
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

        if (status_code = response["StatusCode"]) == 0
          debug "weaveexec ok: #{cmd}"
        else
          logs = container.streaming_logs(stdout: true, stderr: true)
          error "weaveexec exit #{status_code}: #{cmd}\n#{logs}"
        end
        response
      ensure
        container.delete(force: true, v: true) if container
      end
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

  end
end
