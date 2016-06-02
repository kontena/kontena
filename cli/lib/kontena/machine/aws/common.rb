module Kontena
  module Machine
    module Aws
      module Common

        # @param [String] region
        # @return String
        def resolve_ami(region)
          response = Excon.get("https://coreos.com/dist/aws/aws-stable.json")
          images = JSON.parse(response.body)
          info = images[region]
          if info
            info['hvm']
          else
            nil
          end
        end

        # @param [String] vpc_id
        # @param [String] zone
        # @return [Aws::EC2::Types::Subnet, NilClass]
        def default_subnet(vpc_id, zone)
          ec2.subnets({
            filters: [
              {name: "vpc-id", values: [vpc_id]},
              {name: "availability-zone", values: [zone]}
            ]
          }).first
        end

        # @return [Aws::EC2::Types::Vpc, NilClass]
        def default_vpc
          ec2.vpcs({filters: [{name: "is-default", values: ["true"]}]}).first
        end

        

        ##
        # Resolves givne list of group names into group ids
        # @param [String] comma separated list of group names
        # @return [Array]
        def resolve_security_groups_to_ids(group_list, vpc_id)
          ids = group_list.split(',').map { |group|  
            sg = ec2.security_groups({
            filters: [
                {name: 'group-name', values: [group]},
                {name: 'vpc-id', values: [vpc_id]}
              ]
            }).first

            sg ? sg.group_id : nil
          }
          ids.compact
        end
      end
    end
  end
end
