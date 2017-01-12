BALANCE = 'roundrobin'
MODE = 'http'
INTERNAL_PORT = 80
EXTERNAL_PORT = 5000

docker_container -> (container) {
  return unless lb = container.labels['io.kontena.load_balancer.name']
  return unless overlay_cidr = container.labels['io.kontena.container.overlay_cidr']

  name = container.labels['io.kontena.container.name']
  stack = container.labels['io.kontena.stack.name']
  service = container.labels['io.kontena.service.name']
  port = container.labels['io.kontena.load_balancer.internal_port'] || INTERNAL_PORT
  mode = container.labels['io.kontena.load_balancer.mode'] || MODE

  ip = overlay_cidr.split('/')[0]
  lb_service = stack == 'null' ? service : "#{stack}-#{service}"

  lb_service = container.env['KONTENA_LB_SERVICE'] || lb_service

  case mode
  when 'http'
    service_path = "/kontena/haproxy/#{lb}/services/#{lb_service}"

    {
      "#{service_path}/balance" => container.env['KONTENA_LB_BALANCE'] || BALANCE,
      "#{service_path}/basic_auth_secrets" => container.env['KONTENA_LB_BASIC_AUTH_SECRETS'],
      "#{service_path}/cookie" => container.env['KONTENA_LB_COOKIE'],
      "#{service_path}/custom_settings" => container.env['KONTENA_LB_CUSTOM_SETTINGS'],
      "#{service_path}/health_check_uri" => container.labels['io.kontena.health_check.uri'],
      "#{service_path}/keep_virtual_path" => container.env['KONTENA_LB_KEEP_VIRTUAL_PATH'],

      "#{service_path}/virtual_hosts" => container.env['KONTENA_LB_VIRTUAL_HOSTS'],
      "#{service_path}/virtual_path" => container.env['KONTENA_LB_VIRTUAL_PATH'],

      "#{service_path}/upstreams/#{name}" => "#{ip}:#{port}",
    }

  when 'tcp'
    service_path = "/kontena/haproxy/#{lb}/tcp-services/#{lb_service}"

    {
      "#{service_path}/balance" => container.env['KONTENA_LB_BALANCE'] || BALANCE,
      "#{service_path}/custom_settings" => container.env['KONTENA_LB_CUSTOM_SETTINGS'],
      "#{service_path}/external_port" => container.env['KONTENA_LB_EXTERNAL_PORT'] || EXTERNAL_PORT,

      "#{service_path}/upstreams/#{name}" => "#{ip}:#{port}",
    }
  end
}
