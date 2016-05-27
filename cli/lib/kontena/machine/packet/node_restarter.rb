require 'shell-spinner'

module Kontena
  module Machine
    module Packet
      class NodeRestarter
        include RandomName
        include PacketCommon

        attr_reader :client

        # @param [String] token Packet api token
        def initialize(token)
          @client = login(token)
        end

        # @param [String] project_id Packet project id
        # @param [String] token Node hostname
        def run!(project_id, name)
          device = client.list_devices(project_id).find{|d| d.hostname == name}
          abort("Device #{name.colorize(:cyan)} not found in Packet") unless device
          abort("Your version of 'packethost' gem does not support rebooting servers") unless client.respond_to?(:reboot_device)

          ShellSpinner "Restarting Packet device #{device.hostname.colorize(:cyan)} " do
            begin
              response = client.reboot_device(device)
              raise unless response.success?
            rescue
              abort "Cannot delete device #{name.colorize(:cyan)} in Packet"
            end
            sleep 5
            until device && device.state == :active
              device = find_device(project.id, device.hostname) rescue nil
              sleep 5
            end
          end
        end
      end
    end
  end
end
