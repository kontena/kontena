module Kontena
  module Machine
    module Aws
      module Common

        # @param [String] region
        # @return String
        def resolve_ami(region)
          images = {
              'eu-central-1' => 'ami-fee2fb92',
              'ap-northeast-1' => 'ami-26033d48',
              'us-gov-west-1' => 'ami-bdf04cdc',
              'sa-east-1' => 'ami-10c5457c',
              'ap-southeast-2' => 'ami-dc8baebf',
              'ap-southeast-1' => 'ami-6969a50a',
              'us-east-1' => 'ami-23260749',
              'us-west-2' => 'ami-20927640',
              'us-west-1' => 'ami-c2e490a2',
              'eu-west-1' => 'ami-7e72c70d'
          }
          images[region]
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
      end
    end
  end
end
