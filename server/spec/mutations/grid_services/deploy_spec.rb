require_relative '../../spec_helper'

describe GridServices::Deploy do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:host_node) { HostNode.create(node_id: 'aa')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid', initial_size: 1)
    grid.users << user
    grid.host_nodes << host_node
    grid
  }
  let(:deploy_actor) { spy(:deploy_actor) }
  let(:deployer) { spy(:deployer, async: deploy_actor, can_deploy?: true) }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(current_user: user, grid_service: redis_service, strategy: 'ha')}

  describe '#run' do
    it 'checks grid initial node status' do
      expect(grid).to receive(:has_initial_nodes?).once
      subject.run
    end

    it 'sends deploy call to deployer' do
      # since validate method is called in constructor we need to stub deployer method globally before initialization
      allow_any_instance_of(described_class).to receive(:deployer).and_return(deployer)
      expect(deploy_actor).to receive(:deploy).once
      subject.run
    end
  end

  describe '#registry_name' do
    it 'returns DEFAULT_REGISTRY by default' do
      expect(subject.registry_name).to eq(GridServices::Deploy::DEFAULT_REGISTRY)
    end

    it 'returns registry from image' do
      subject.grid_service.image_name = 'kontena.io/admin/redis:2.8'
      expect(subject.registry_name).to eq('kontena.io')
    end
  end

  describe '#creds_for_registry' do
    it 'return nil by default' do
      expect(subject.creds_for_registry).to be_nil
    end
  end
end
