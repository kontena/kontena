module V1
  class StacksApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers

    plugin :multi_route
    plugin :streaming

    Dir[File.join(__dir__, '/stacks/*.rb')].each{|f| require f}

    route do |r|
      validate_access_token
      require_current_user

      ##
      # @param [String] name
      # @return [Grid]
      def load_grid(name)
        @grid = current_user.accessible_grids.find_by(name: name)
        halt_request(404, {error: 'Not found'}) unless @grid
      end

      def update_stack(stack, data)
        data[:grid] = @grid
        data[:current_user] = current_user
        data[:stack] = stack
        outcome = Stacks::Update.run(data)

        if outcome.success?
          @stack = outcome.result
          audit_event(request, @grid, @stack, 'update')
          response.status = 200
          render('stacks/show')
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end


      def delete_stack(stack)
        outcome = Stacks::Delete.run(stack: stack, current_user: current_user)

        if outcome.success?
          audit_event(request, @grid, @stack, 'delete')
          response.status = 200
          {}
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      def deploy_stack(stack)
        outcome = Stacks::Deploy.run(stack: stack, current_user: current_user)

        if outcome.success?
          audit_event(request, @grid, @stack, 'deploy')
          response.status = 200
          {}
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      end

      # /v1/stacks/:grid/
      r.on ':grid/:name' do |grid, name|

        load_grid(grid)
        @stack = @grid.stacks.find_by(name: name)
        unless @stack
          halt_request(404)
        end

        r.post do
          r.on ':deploy' do
            deploy_stack(@stack)
          end
        end

        r.put do
          # PUT /v1/stacks/:grid/:name
          r.is do
            data = parse_json_body
            update_stack(@stack, data)
          end
        end

        # GET /v1/stacks/:grid/:name
        r.get do
          r.is do
            render('stacks/show')
          end

          r.on "container_logs" do
            r.route 'stack_container_logs'
          end
        end

        r.delete do
          r.is do
            delete_stack(@stack)
          end
        end
      end
    end
  end
end
