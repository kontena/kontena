module V1
  class VolumesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers

    plugin :backtracking_array

    route do |r|

      validate_access_token
      require_current_user

      def find_grid(grid_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: "Grid #{grid_name} not found"}) if !grid
        unless current_user.has_access?(grid)
          halt_request(403, {error: 'Access denied'})
        end
        grid
      end

      # @param [String] grid_name
      # @param [String] stack_name
      # @param [String] volume_name
      # @return [GridService]
      def load_volume(volume_name)
        volume = @grid.volumes.find_by(name: volume_name)
        halt_request(404, {error: "Volume #{volume_name} not found"}) unless volume
        volume
      end

      r.on ':grid_name' do |grid_name|
        @grid = find_grid(grid_name)
        r.get do
          r.is do
            @volumes = @grid.volumes.includes(:grid)
            render('volumes/index')
          end
          r.is ':volume' do |volume|
            @volume = load_volume(volume)
            render('volumes/show')
          end
        end
        r.post do
          r.is do
            data = parse_json_body rescue {}
            data[:grid] = @grid
            outcome = Volumes::Create.run(data)
            if outcome.success?
              @volume = outcome.result
              audit_event(r, @volume.grid, @volume, 'create', @volume)
              response.status = 201
              render('volumes/show')
            else
              response.status = 422
              {error: outcome.errors.message}
            end
          end

          r.on 'plugins' do
            r.on 'install' do
              puts "****** plugins/install"
              data = parse_json_body rescue {}
              data[:grid] = @grid
              outcome = Volumes::PluginInstall.run(data)
              if outcome.success?
                #@volume = outcome.result
                #audit_event(r, @volume.grid, @volume, 'create', @volume)
                response.status = 201
                #render('volumes/show')
                {}
              else
                response.status = 422
                {error: outcome.errors.message}
              end
            end
            
          end
          
        end
        r.delete do
          r.is ':volume' do |volume|
            @volume = load_volume(volume)
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
