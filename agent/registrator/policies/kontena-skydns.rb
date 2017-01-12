config do
  json_attr :domain, default: 'kontena.local'
end

helpers do
  def skydns_path(dns)
    File.join(['/skydns', dns.split('.').reverse].flatten)
  end
end

docker_container -> (container) {
  return unless overlay_cidr = container.labels['io.kontena.container.overlay_cidr']

  grid = container.labels['io.kontena.grid.name']
  stack = container.labels['io.kontena.stack.name']
  service = container.labels['io.kontena.service.name']
  instance_number = container.labels['io.kontena.service.instance_number']

  hostname = "#{service}-#{instance_number}"
  ip = overlay_cidr.split('/')[0]

  Hash.new.tap { |nodes|
    # legacy service?
    if stack == 'null'
      nodes[skydns_path("#{hostname}.#{config.domain}")] = {host: ip}
      nodes[skydns_path("#{instance_number}.#{service}.#{config.domain}")] = {host: ip}
    end

    # stack or grid domain
    if stack == 'null'
      nodes[skydns_path("#{hostname}.#{grid}.#{config.domain}")] = {host: ip}
      nodes[skydns_path("#{instance_number}.#{service}.#{grid}.#{config.domain}")] = {host: ip}
    else
      nodes[skydns_path("#{hostname}.#{stack}.#{grid}.#{config.domain}")] = {host: ip}
      nodes[skydns_path("#{instance_number}.#{service}.#{stack}.#{grid}.#{config.domain}")] = {host: ip}
    end

    # exposed stack service?
    if container.labels['io.kontena.service.exposed']
      nodes[skydns_path("#{instance_number}.#{stack}.#{grid}.#{config.domain}")] = {host: ip}
      nodes[skydns_path("#{stack}-#{instance_number}.#{grid}.#{config.domain}")] = {host: ip}
    end
  }
}
