module V1
  class VolumesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers



    #require_glob File.join(__dir__, '/services/*.rb')

    route do |r|

      validate_access_token
      require_current_user

      def find_grid(grid_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: "Grid #{grid_name} not found"}) if !grid
        grid
      end

      def find_stack(stack_name, grid)
        stack = grid.stacks.find_by(name: stack_name)
        halt_request(404, {error: "Stack #{stack_name} not found"}) if !stack
        stack
      end

      # @param [String] grid_name
      # @param [String] stack_name
      # @param [String] volume_name
      # @return [GridService]
      def load_volume(grid_name, stack_name, volume_name)
        grid = find_grid(grid_name)
        stack = find_stack(stack_name, grid)
        volume = stack.volumes.find_by(name: volume_name)
        halt_request(404, {error: "Volume #{volume_name} not found"}) if !volume

        unless current_user.grid_ids.include?(volume.grid_id)
          halt_request(403, {error: 'Access denied'})
        end

        volume
      end

      r.on ':grid_name' do |grid_name|
        @grid = find_grid(grid_name)
        r.get do
          r.is do
            @volumes = @grid.volumes
            render('volumes/index')
          end
          r.on ':stack_name/:volume_name' do |stack_name, volume_name|
            @volume = load_volume(grid_name, stack_name, volume_name)
            render('volumes/show')
          end
        end
        r.post do
          r.on ':stack_name' do |stack_name|
            r.is do
              grid = find_grid(grid_name)
              stack = find_stack(stack_name, grid)
              data = parse_json_body rescue {}
              data[:grid] = grid
              data[:stack] = stack
              outcome = Volumes::Create.run(data)
              if outcome.success?
                volume = outcome.result
                audit_event(r, volume.grid, volume, 'create', volume)
                @volume = outcome.result
                response.status = 201
                render('volumes/show')
              else
                response.status = 422
                {error: outcome.errors.message}
              end

            end
          end
        end
        r.delete do
          r.on ':stack_name/:volume_name' do |stack_name, volume_name|
            r.is do
              @volume = load_volume(grid_name, stack_name, volume_name)
              outcome = Volumes::Delete.run(volume: @volume)
              if outcome.success?
                audit_event(r, @volume.grid, @volume, 'delete', @volume)
                @volume = outcome.result
                {}
              else
                response.status = 422
                {error: outcome.errors.message}
              end
            end
          end
        end

      end

    end
  end
end
