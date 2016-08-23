module V1
  class StacksApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :multi_route

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

      def create_stack(data)
        data[:grid] = @grid
        data[:current_user] = current_user
        outcome = Stacks::Create.run(data)

        if outcome.success?
          @stack = outcome.result
          audit_event(request, @grid, @stack, 'create')
          response.status = 201
          render('stacks/show')
        else
          response.status = 422
          {error: outcome.errors.message}
        end
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
      r.on ':grid' do |grid|
        
        load_grid(grid)

        r.post do
          r.is do
            data = parse_json_body
            create_stack(data)
          end

          r.on ':name/deploy' do |name|
            @stack = @grid.stacks.find_by(name: name)
            if @stack
              deploy_stack(@stack)
            else
              response.status = 404
            end
          end
        end

        r.put do
          # PUT /v1/stacks/:grid/:name
          r.on ':name' do |name|
            @stack = @grid.stacks.find_by(name: name)
            data = parse_json_body
            if @stack
              update_stack(@stack, data)
            else
              response.status = 404
            end
          end
        end

        # GET /v1/stacks/:grid/
        r.get do
          r.is do
            @stacks = @grid.stacks
            render('stacks/index')
          end
          # GET /v1/stacks/:grid/:name
          r.on ':name' do |name|
            @stack = @grid.stacks.find_by(name: name)
            if @stack
              render('stacks/show')
            else
              response.status = 404
            end
          end
        end

        r.delete do
          r.on ':name' do |name|
            @stack = @grid.stacks.find_by(name: name)
            if @stack
              delete_stack(@stack)
            else
              response.status = 404
            end
          end
        end

      end
    end
  end
end
