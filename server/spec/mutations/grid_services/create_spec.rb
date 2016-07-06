require_relative '../../spec_helper'

describe GridServices::Create do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:linked_service) { GridService.create(grid: grid, name: 'linked-service', image_name: 'redis:2.8')}

  describe '#run' do
    it 'creates a new grid service' do
      expect {
        described_class.new(
          current_user: user,
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true
        ).run
      }.to change{ GridService.count }.by(1)
    end

    it 'allows - char in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        image: 'redis:2.8',
        name: 'redis-db',
        stateful: true
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'allows numbers in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        image: 'redis:2.8',
        name: 'redis-12',
        stateful: true
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'does not allow - as a first char in name' do
      outcome = described_class.new(
        current_user: user,
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
        current_user: user,
        grid: grid,
        image: 'redis:2.8',
        name: 'red&is',
        stateful: true
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow duplicate name within a grid' do
      GridService.create!(name: 'redis', image_name: 'redis:latest', grid: grid)
      outcome = described_class.new(
        current_user: user,
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
          current_user: user,
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          container_count: 3
      ).run
      expect(outcome.result.container_count).to eq(3)
    end

    it 'saves user' do
      outcome = described_class.new(
          current_user: user,
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          user: 'redis'
      ).run
      expect(outcome.result.user).to eq('redis')
    end

    it 'saves cpu_shares' do
      outcome = described_class.new(
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
        {name: linked_service.name, alias: 'link-alias'}
      ]
      outcome = described_class.new(
          current_user: user,
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
          current_user: user,
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: true,
          volumes: ['/data1', '/data2']
      ).run
      expect(outcome.result.volumes).to eq(['/data1', '/data2'])
    end

    it 'saves volumes_from' do
      outcome = described_class.new(
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
          current_user: user,
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false
      ).run
      expect(outcome.result.revision).to eq(1)
    end
    
    it 'saves health_check' do
      outcome = described_class.new(
          current_user: user,
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
          current_user: user,
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
          current_user: user,
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
  end
end
