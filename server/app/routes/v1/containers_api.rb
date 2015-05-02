%w(create).each do |command|
  require_relative "../../mutations/containers/#{command}"
end

module V1
  class ContainersApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user

      # /v1/containers/:id
      r.on ':id' do |id|
        container = Container.find_by(name: id)
        if !container
          halt_request(404, {error: 'Not found'}) and return
        end
        unless current_user.grid_ids.include?(container.grid_id)
          halt_request(403, {error: 'Access denied'}) and return
        end

        # GET /v1/containers/:id
        r.get do

          r.is do
            @container = container
            render('containers/show')
          end

          r.on 'top' do
            client = RpcClient.new(container.host_node.host_id)
            client.request('/containers/top', container.container_id, {})
          end

          r.on 'logs' do
            @logs = container.container_logs.order(created_at: :desc).limit(500).to_a.reverse
            render('container_logs/index')
          end
        end

        # POST /v1/containers/:id
        r.post do
          r.on 'exec' do
            json = parse_json_body
            Docker::ContainerExecutor.new(container).exec_in_container(json['cmd'])
          end
        end

        # DELETE /v1/containers/:id
        r.delete do
          r.on('logs') do
            container.container_logs.delete_all
          end
        end
      end
    end
  end
end
