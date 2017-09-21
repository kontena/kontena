
describe GridServices::Create do
  let(:grid) {
    Grid.create!(name: 'test-grid')
  }
  let(:linked_service) {
    GridService.create!(grid: grid, name: 'linked-service', image_name: 'redis:2.8')
  }

  describe '#run' do
    it 'creates a new grid service' do
      expect {
        described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true
        ).run
      }.to change{ GridService.count }.by(1)
    end

    it 'allows - char in name' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'redis-db',
        stateful: true
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'allows numbers in name' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'redis-12',
        stateful: true
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'does not allow - as a first char in name' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: '-redis',
        stateful: true
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow special chars in name' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'red&is',
        stateful: true
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow newlines in name' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: "foo\nbar",
        stateful: true
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.symbolic).to eq 'name' => :matches
    end

    it 'does not allow a name that is too long' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxxx39',
        stateful: true
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'name' => 'Total grid service name length 65 is over limit (64): xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxxx39-1.test-grid.kontena.local'
    end

    it 'does not allow a name that is too long for the number of instances' do
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxx38',
        stateful: true,
        instances: 10
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'name' => 'Total grid service name length 65 is over limit (64): xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxx38-10.test-grid.kontena.local'
    end

    it 'does not allow duplicate name within a grid' do
      GridService.create!(name: 'redis', image_name: 'redis:latest', grid: grid)
      outcome = described_class.new(
        grid: grid,
        image: 'redis:2.8',
        name: 'redis',
        stateful: true
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'saves container_count' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          container_count: 3
      ).run
      expect(outcome.result.container_count).to eq(3)
    end

    it 'saves instances to container_count' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          instances: 3
      ).run
      expect(outcome.result.container_count).to eq(3)
    end

    it 'saves user' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          user: 'redis'
      ).run
      expect(outcome.result.user).to eq('redis')
    end

    it 'saves cpus' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          cpus: 2
      ).run
      expect(outcome.result.cpus).to eq(2)
    end

    it 'saves cpu_shares' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          cpu_shares: 200
      ).run
      expect(outcome.result.cpu_shares).to eq(200)
    end

    it 'saves memory' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          memory: 512.megabytes
      ).run
      expect(outcome.result.memory).to eq(512.megabytes)
    end

    it 'saves memory_swap' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          memory_swap: 512.megabytes
      ).run
      expect(outcome.result.memory_swap).to eq(512.megabytes)
    end

    it 'saves cmd' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          cmd: ['redis', '-h']
      ).run
      expect(outcome.result.cmd).to eq(['redis', '-h'])
    end

    it 'saves entrypoint' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          entrypoint: '/start.sh'
      ).run
      expect(outcome.result.entrypoint).to eq('/start.sh')
    end

    it 'saves env' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          env: ['FOO=BAR', 'BAR=BAZ']
      ).run
      expect(outcome.result.env).to eq(['FOO=BAR', 'BAR=BAZ'])
    end

    it 'saves ports' do
      ports = [
          {ip: '0.0.0.0', protocol: 'tcp', node_port: 6379, container_port: 6379},
          {ip: '10.10.10.10', protocol: 'tcp', node_port: 6379, container_port: 6379}
      ]
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          ports: ports
      ).run
      expect(outcome.result.ports).to eq(ports.map{|p| p.stringify_keys})
    end

    it 'saves links' do
      links = [
        {name: "#{linked_service.stack.name}/#{linked_service.name}", alias: 'link-alias'}
      ]
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          links: links
      ).run
      expect(outcome.result.grid_service_links.size).to eq(1)
      expect(outcome.result.grid_service_links.first.linked_grid_service).to eq(linked_service)
    end

    it 'saves volumes' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          volumes: ['/data1', '/data2']
      ).run
      expect(outcome.result.service_volumes.count).to eq(2)
    end

    it 'saves volumes_from' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          volumes_from: ['linked-service-%s']
      ).run
      expect(outcome.result.volumes_from).to eq(['linked-service-%s'])
    end

    it 'returns error if service is stateful and volumes_from is specified' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          volumes_from: ['linked-service-%s']
      ).run
      expect(outcome.success?).to be_falsey
    end

    it 'saves privileged' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          privileged: true
      ).run
      expect(outcome.result.privileged).to eq(true)
    end

    it 'saves cap_add' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          cap_add: ['NET_ADMIN']
      ).run
      expect(outcome.result.cap_add).to eq(['NET_ADMIN'])
    end

    it 'saves cap_drop' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          cap_drop: ['SETUID']
      ).run
      expect(outcome.result.cap_drop).to eq(['SETUID'])
    end

    it 'saves revision as 1 by default' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false
      ).run
      expect(outcome.result.revision).to eq(1)
    end

    it 'attaches default network when net mode is bridge' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false
      ).run
      expect(outcome.result.networks.count).to eq(1)
      expect(outcome.result.networks.first.name).to eq('kontena')
    end

    it 'saves health_check' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          health_check: {
            protocol: 'http',
            uri: '/health',
            interval: 120,
            timeout: 5,
            initial_delay: 10,
            port: 5000
          }
      ).run
      expect(outcome.result.health_check).not_to be_nil
      expect(outcome.result.health_check.uri).to eq('/health')
    end

    it 'fails to save health_check, no port defined' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          health_check: {
            uri: '/health',
            interval: 120,
            timeout: 5,
            initial_delay: 10
          }
      ).run
      expect(outcome.success?).to be(false)
    end

    it 'fails to save health_check, interval < timeout' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          health_check: {
            protocol: 'tcp',
            interval: 10,
            timeout: 50,
            initial_delay: 10,
            port: 1234
          }
      ).run
      expect(outcome.success?).to be(false)
    end

    it 'fails to save health_check, port 0' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          health_check: {
            protocol: 'tcp',
            interval: 10,
            timeout: 5,
            initial_delay: 10,
            port: 0
          }
      ).run
      expect(outcome.success?).to be(false)
    end

    it 'fails to save health_check, port over range' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          health_check: {
            protocol: 'tcp',
            interval: 10,
            timeout: 5,
            initial_delay: 10,
            port: 70000
          }
      ).run
      expect(outcome.success?).to be(false)
    end

    it 'fails validating secret existence' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          secrets: [
            {secret: 'NON_EXISTING_SECRET', name: 'SOME_SECRET'}
          ]
      ).run
      expect(outcome.success?).to be(false)
    end

    context 'with a grid secret' do
      let :secret do
        GridSecret.create!(grid: grid, name: 'EXISTING_SECRET', value: 'secret')
      end

      before do
        secret
      end

      it 'saves service secret' do
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            secrets: [
              {secret: 'EXISTING_SECRET', name: 'SOME_SECRET'}
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.secrets.map{|s| s.attributes}).to match [hash_including(
            'secret' => 'EXISTING_SECRET',
            'type' => 'env',
            'name' => 'SOME_SECRET',
        )]
      end

      it 'maps the same service secret twice' do
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            secrets: [
              {secret: 'EXISTING_SECRET', name: 'SOME_SECRET'},
              {secret: 'EXISTING_SECRET', name: 'SOME_SECRET2'},
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.secrets.map{|s| s.attributes}).to match [
          hash_including(
            'secret' => 'EXISTING_SECRET',
            'type' => 'env',
            'name' => 'SOME_SECRET',
          ),
          hash_including(
            'secret' => 'EXISTING_SECRET',
            'type' => 'env',
            'name' => 'SOME_SECRET2',
          ),
        ]
      end
    end

    context 'with service_certificate' do
      let :certificate do
        Certificate.create!(grid: grid,
          subject: 'kontena.io',
          valid_until: Time.now + 90.days,
          private_key: 'private_key',
          certificate: 'certificate')
      end

      before do
        certificate
      end

      it 'saves service cert' do
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            certificates: [
              {subject: 'kontena.io', name: 'SSL_CERT'}
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.certificates.map{|s| s.attributes}).to match [hash_including(
            'subject' => 'kontena.io',
            'type' => 'env',
            'name' => 'SSL_CERT',
        )]
      end

      it 'fails to create service with invalid certificates' do
        outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          certificates: [
            {subject: 'kotnena.io', name: 'SSL_CERT'}
          ]
        ).run
        expect(outcome).to_not be_success
      end
    end

    it 'validates env syntax' do
      outcome = described_class.new(
        grid: grid,
        name: 'redis',
        image: 'redis:2.8',
        stateful: false,
        env: [
          'FOO',
        ],
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'env' => [ "Env[0] isn't in the right format" ]
    end

    it 'saves stop_grace_period with default if not given' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false
      ).run
      expect(outcome.result.stop_grace_period).to eq(10)
    end

    it 'fails to save with unknown grace_period' do
      outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          stop_grace_period: 'foo'
      ).run
      expect(outcome).not_to be_success
    end

    context 'hooks' do
      it 'saves post_start hooks' do
        outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          hooks: {
            post_start: [
              {
                name: 'sleep', cmd: 'sleep 10', instances: 1, oneshot: true
              }
            ]
          }
        ).run
        expect(outcome).to be_success
        expect(outcome.result.hooks.size).to eq(1)
      end

      it 'saves pre_start hooks' do
        outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          hooks: {
            pre_start: [
              {
                name: 'sleep', cmd: 'sleep 10', instances: 1, oneshot: true
              }
            ]
          }
        ).run
        expect(outcome).to be_success
        expect(outcome.result.hooks.size).to eq(1)
      end

      it 'saves pre_stop hooks' do
        outcome = described_class.new(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          hooks: {
            pre_stop: [
              {
                name: 'sleep', cmd: 'sleep 10', instances: 1, oneshot: true
              }
            ]
          }
        ).run
        expect(outcome).to be_success
        expect(outcome.result.hooks.size).to eq(1)
      end
    end

    context 'volumes' do
      let(:volume) do
        Volume.create!(grid: grid, name: 'foo', scope: 'node')
      end

      it 'creates service with a real volume' do
        volume
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            volumes: [
              'foo:/data:ro'
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.service_volumes.first.volume).to eq(volume)
      end

      it 'creates service with a bind mount' do
        volume
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            volumes: [
              '/foo:/data:ro,nocopy,rslave'
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.service_volumes.first.volume).to be_nil
        expect(outcome.result.service_volumes.first.bind_mount).to eq('/foo')
        expect(outcome.result.service_volumes.first.path).to eq('/data')
        expect(outcome.result.service_volumes.first.flags).to eq('ro,nocopy,rslave')
      end

      it 'creates service with a anon volumes' do
        volume
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            volumes: [
              '/foo',
              '/bar'
            ]
        ).run
        expect(outcome.success?).to be(true)
        expect(outcome.result.service_volumes.count).to eq(2)
        expect(outcome.result.service_volumes.first.volume).to be_nil
        expect(outcome.result.service_volumes.first.bind_mount).to eq(nil)
        expect(outcome.result.service_volumes.first.path).to eq('/foo')
        expect(outcome.result.service_volumes.first.flags).to eq(nil)

        expect(outcome.result.service_volumes[1].volume).to be_nil
        expect(outcome.result.service_volumes[1].bind_mount).to eq(nil)
        expect(outcome.result.service_volumes[1].path).to eq('/bar')
        expect(outcome.result.service_volumes[1].flags).to eq(nil)
      end

      it 'fails to create service with invalid volume' do
        outcome = described_class.new(
            grid: grid,
            image: 'redis:2.8',
            name: 'redis',
            stateful: false,
            volumes: [
              'foo'
            ]
        ).run
        expect(outcome.success?).to be(false)
      end

    end
  end
end
