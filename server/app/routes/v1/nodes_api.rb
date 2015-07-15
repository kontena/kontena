require_relative '../../mutations/host_nodes/register'

module V1
  class NodesApi < Roda
    include RequestHelpers

    route do |r|

      token = r.env['HTTP_KONTENA_GRID_TOKEN']
      grid = Grid.find_by(token: token.to_s)
      halt_request(404, {error: 'Not found'}) unless grid

      r.post do
        r.is do
          data = parse_json_body
          outcome = HostNodes::Register.run(
            grid: grid,
            id: data['id'],
            private_ip: data['private_ip']
          )
          if outcome.success?
            @node, is_new = outcome.result
            response.status = 201 if is_new
          else
            halt_request(422, {error: outcome.errors.message})
          end

          render('host_nodes/show')
        end
      end

      r.get do
        r.on :id do |id|
          @node = grid.host_nodes.find_by(node_id: id)
          halt_request(404, {error: 'Node not found'}) if !@node

          render('host_nodes/show')
        end
      end
    end
  end
end
