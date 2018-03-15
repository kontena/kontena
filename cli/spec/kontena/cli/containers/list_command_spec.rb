require "kontena/cli/containers/list_command"

describe Kontena::Cli::Containers::ListCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(client).to receive(:get).with('containers/test-grid').and_return({'containers' => containers})

    # supress spinner output
    allow(subject).to receive(:spin_if) do |&block|
      block.call
    end

    # fake time durations
    allow(subject).to receive(:time_ago).and_return('xxx days ago')
  end

  context "without any containers" do
    let(:containers) { [] }

    it "lists nothing" do
      expect{subject.run([])}.to output_table([

      ]).with_header(['ID', 'IMAGE', 'CMD', 'CREATED_AT', 'STATE'])
    end
  end

  context "with a container" do
    let(:containers) { [
        JSON.load(<<-EOM
          {"id":"development/core-01/hooks-prestart-fail.redis-1","name":"hooks-prestart-fail.redis-1","container_id":"0f4e01165038011f7f851b0aeb9cdb1d6db1045905da731884f4efb807e6c639","grid_id":"development","node":{"id":"XI4K:NPOL:EQJ4:S4V7:EN3B:DHC5:KZJD:F3U2:PCAN:46EV:IO4A:63S5","connected":false,"last_seen_at":"2018-03-12T20:39:17.163Z","name":"core-01","labels":["region=test","test","provider=vagrant"],"public_ip":"82.181.224.117","private_ip":"192.168.66.101","node_number":1,"grid":{"id":"development","name":"development","initial_size":1}},"service_id":null,"created_at":"2017-10-02T14:43:19.227Z","updated_at":"2017-10-02T14:43:19.223Z","started_at":"2017-10-02T14:42:51.046Z","finished_at":"0001-01-01T00:00:00.000Z","deleted_at":"2018-03-12T20:39:43.944Z","status":"deleted","state":{"error":"","exit_code":0,"pid":24899,"oom_killed":false,"paused":false,"restarting":false,"dead":false,"running":true},"deploy_rev":"2017-10-02 14:14:48 UTC","service_rev":"1","instance_number":1,"image":"redis:latest","cmd":["/bin/sh","-c","echo pre-start hook"],"env":["KONTENA_SERVICE_ID=59d249d76cbee100086b83f2","KONTENA_SERVICE_NAME=redis","KONTENA_GRID_NAME=development","KONTENA_PLATFORM_NAME=development","KONTENA_STACK_NAME=hooks-prestart-fail","KONTENA_NODE_NAME=core-01","KONTENA_SERVICE_INSTANCE_NUMBER=1","PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","GOSU_VERSION=1.10","REDIS_VERSION=4.0.2","REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-4.0.2.tar.gz","REDIS_DOWNLOAD_SHA=b1a0915dbc91b979d06df1977fe594c3fa9b189f1f3d38743a2948c9f7634813"],"volumes":[],"ip_address":"10.81.128.90","hostname":"redis-1","domainname":"hooks-prestart-fail.development.kontena.local","network_settings":{"bridge":"","gateway":"172.17.43.1","ip_address":"172.17.0.1","ip_prefix_len":16,"mac_address":"02:42:ac:11:00:01","port_mapping":null,"ports":{}}}
          EOM
        )
    ] }

    it "lists the container" do
      expect{subject.run([])}.to output_table([
        ['core-01/hooks-prestart-fail.redis-1', 'redis:latest', '"/bin/sh -c echo pre-start.."', 'xxx days ago', 'running'],
      ]).with_header(['CONTAINER_ID', 'IMAGE', 'COMMAND', 'CREATED', 'STATUS'])
    end
  end
end
