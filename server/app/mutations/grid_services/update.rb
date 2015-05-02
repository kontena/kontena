module GridServices
  class Update < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service, class: GridService
    end

    optional do
      string :image
      integer :container_count
      string :user
      integer :cpu_shares, min: 0, max: 1024
      integer :memory
      integer :memory_swap
      array :cap_add do
        string
      end
      array :cap_drop do
        string
      end
      array :cmd do
        string
      end
      string :entrypoint
      array :env do
        string
      end
      array :ports do
        hash do
          required do
            string :ip, default: '0.0.0.0'
            string :protocol, default: 'tcp'
            integer :node_port
            integer :container_port
          end
        end
      end
    end

    def execute
      attributes = {}
      attributes[:image_name] = self.image if self.image
      attributes[:container_count] = self.container_count if self.container_count
      attributes[:user] = self.user if self.user
      attributes[:cpu_shares] = self.cpu_shares if self.cpu_shares
      attributes[:memory] = self.memory if self.memory
      attributes[:memory_swap] = self.memory_swap if self.memory_swap
      attributes[:cap_add] = self.cap_add if self.cap_add
      attributes[:cap_drop] = self.cap_drop if self.cap_drop
      attributes[:cmd] = self.cmd if self.cmd
      attributes[:env] = merge_env(grid_service.env, self.env) if self.env
      attributes[:ports] = self.ports if self.ports
      grid_service.attributes = attributes
      grid_service.save

      grid_service
    end

    ##
    # @param [Array<String>] env1
    # @param [Array<String>] env2
    # @return [Array<String>]
    def merge_env(env1, env2)
      env1_hash = env1.inject({}){|h, n| h[n.split('=', 2)[0]] = n.split('=', 2)[1]; h }
      env2_hash = env2.inject({}){|h, n| h[n.split('=', 2)[0]] = n.split('=', 2)[1]; h }
      env1_hash.merge(env2_hash).map{|k, v| "#{k}=#{v}"}
    end
  end
end
