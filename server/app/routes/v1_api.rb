module V1

  require_glob File.expand_path('../v1/*.rb', __FILE__)

  class Api < Roda
    route do |r|
      r.on 'ping',                proc { r.run PingApi }
      r.on 'audit_logs',          proc { r.run AuditLogsApi }
      r.on 'config',              proc { r.run ConfigApi }
      r.on 'auth',                proc { r.run AuthApi }
      r.on 'user',                proc { r.run UserApi }
      r.on 'users',               proc { r.run UsersApi }
      r.on 'grids',               proc { r.run GridsApi }
      r.on 'nodes',               proc { r.run NodesApi }
      r.on 'services',            proc { r.run ServicesApi }
      r.on 'containers',          proc { r.run ContainersApi }
      r.on 'external_registries', proc { r.run ExternalRegistriesApi }
      r.on 'etcd',                proc { r.run EtcdApi }
      r.on 'secrets',             proc { r.run SecretsApi }
      r.on 'stacks',              proc { r.run StacksApi }
      r.on 'certificates',        proc { r.run CertificatesApi }
      r.on 'volumes',             proc { r.run VolumesApi }
      r.on 'domain_authorizations', proc { r.run DomainAuthorizationsApi }
    end
  end
end
