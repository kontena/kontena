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
        #
        # @param tag_list [Array] array of string where each string looks like 'key=value'
        # @param ec2_instance [] the instance to add tags to
        # @param name [String] name of the instance
        def add_tags(tag_list, ec2_instance, name)
          tags = [
            {key: 'Name', value: name}
          ]
          if tag_list && !tag_list.empty?
            tag_list.each { |tag|
              key, value = tag.split('=')
              tags << {key: key, value: value}
            }
          end
          ec2_instance.create_tags({
            tags: tags
          })
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
