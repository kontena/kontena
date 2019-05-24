module Kontena::NetworkAdapters
  class ContainerAttacher
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    OVERLAY_SUFFIX = '16'

    attr_reader :container

    # @param container [Docker::Container]
    def initialize(container)
      @container = container
    end

    # @param [String] hostname
    # @param [String] service_name
    # @param [String] domain_name
    # @return [Array<String>]
    def default_stack_dns_names(hostname, service_name, domain_name)
      base_domain = domain_name.split('.', 2)[1]
      [
        "#{hostname}.#{base_domain}",
        "#{service_name}.#{base_domain}"
      ]
    end

    # @param [String] hostname
    # @param [String] service_name
    # @param [String] domain_name
    # @return [Array<String>]
    def stack_dns_names(hostname, service_name, domain_name)
      [
        "#{service_name}.#{domain_name}",
        "#{hostname}.#{domain_name}"
      ]
    end

    # @param [String] instance_number
    # @param [String] domain_name
    # @return [Array<String>]
    def exposed_stack_dns_names(instance_number, domain_name)
      stack, base_domain = domain_name.split('.', 2)
      [
        domain_name,
        "#{stack}-#{instance_number}.#{base_domain}"
      ]
    end

    # @return [Array<String>]
    def dns_names
      grid_name = container.labels['io.kontena.grid.name']
      service_name = container.labels['io.kontena.service.name']
      instance_number = container.labels['io.kontena.service.instance_number']
      if container.config['Domainname'].to_s.empty?
        domain_name = "#{grid_name}.kontena.local"
      else
        domain_name = container.config['Domainname']
      end
      if container.default_stack?
        if container.labels['io.kontena.stack.name']
          hostname = container.config['Hostname']
        else
          hostname = container.labels['io.kontena.container.name'] # legacy container
        end
        dns_names = default_stack_dns_names(hostname, service_name, domain_name)
        dns_names = dns_names + stack_dns_names(hostname, service_name, domain_name)
      else
        hostname = container.config['Hostname']
        dns_names = stack_dns_names(hostname, service_name, domain_name)
        if container.labels['io.kontena.service.exposed']
          dns_names = dns_names + exposed_stack_dns_names(instance_number, domain_name)
        end
      end

      dns_names
    end

    def attach(attached_cidrs: nil)
      if container.overlay_network
        weaveexec_attach(container.overlay_cidr)
      else
        # overlay network migration for 0.16 compat
        # override overlay network /19 -> /16 suffix for existing containers that may need to be migrated
        overlay_cidr = "#{container.overlay_ip}/#{OVERLAY_SUFFIX}"

        # check for un-migrated containers cached at start
        if attached_cidrs
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} from #{migrate_cidrs} to #{overlay_cidr}"

          migrate_container(overlay_cidr, migrate_cidrs)
        else
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} (not attached) -> #{overlay_cidr}"

          weaveexec_attach(overlay_cidr)
        end
      end
    end

    # @param [Docker::Container]
    def register_container_dns
      dns_names.each do |name|
        weave_client.add_dns(container.id, container.overlay_ip, name)
      end
    end

  private
    # @return [Kontena::NetworkAdapters::WeaveClient]
    def weave_client
      @weave_client ||= Kontena::NetworkAdapters::WeaveClient.new
    end

    # Attach container to weave with given CIDR address, first detaching any existing mismatching addresses
    #
    # @param [String] container_id
    # @param [String] overlay_cidr '10.81.X.Y/16'
    # @param [Array<String>] migrate_cidrs ['10.81.X.Y/19']
    def migrate_container(cidr, attached_cidrs)
      # first remove any existing addresses
      # this is required, since weave will not attach if the address already exists, but with a different netmask
      attached_cidrs.each do |attached_cidr|
        if cidr != attached_cidr
          warn "Migrate container=#{container.id} from cidr=#{attached_cidr}"
          weaveexec! 'detach', attached_cidr, container.id
        end
      end

      # attach with the correct address
      weaveexec_attach(cidr)
    end

    # Attach container to weave with given CIDR address
    #
    def weaveexec_attach(cidr)
      info "Attach container=#{container.id} at cidr=#{cidr}"

      weaveexec! 'attach', cidr, '--rewrite-hosts', container.id
    end
  end
end
