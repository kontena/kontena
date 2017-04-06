module Kontena
  module Cli
    autoload :VERSION, 'kontena/cli/version'
    autoload :Helpers, 'kontena/cli/helpers'
    autoload :Common, 'kontena/cli/common'
    autoload :Spinner, 'kontena/cli/spinner'
    autoload :GridOptions, 'kontena/cli/grid_options'
    autoload :Plugins, 'kontena/cli/plugins'
    autoload :Grids, 'kontena/cli/grids'
    autoload :Stacks, 'kontena/cli/stacks'
    autoload :Volumes, 'kontena/cli/volumes'
    autoload :Nodes, 'kontena/cli/nodes'
    autoload :Apps, 'kontena/cli/apps'
    autoload :Etcd, 'kontena/cli/etcd'
    autoload :Containers, 'kontena/cli/containers'
    autoload :Registry, 'kontena/cli/registry'
    autoload :ExternalRegistries, 'kontena/cli/external_registries'
    autoload :Vpn, 'kontena/cli/vpn'
    autoload :Certificate, 'kontena/cli/certificate'
    autoload :Cloud, 'kontena/cli/cloud'
    autoload :Vault, 'kontena/cli/vault'
  end
end
