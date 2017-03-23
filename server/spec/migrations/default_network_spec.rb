require_relative '../../db/migrations/16_default_network'

describe DefaultNetwork do

  let(:grid) {
    grid = Grid.create!(name: 'foo')
    grid.networks.delete_all
    GridService.create!(
      name: 'app',
      grid: grid,
      image_name: 'my/app:latest'
    )
    grid
  }

  let(:another_grid) {
    another_grid = Grid.create!(name: 'bar')
    another_grid.networks.delete_all
    GridService.create!(
      name: 'app',
      grid: another_grid,
      image_name: 'my/app:latest'
    )
    another_grid
  }

  let(:service_with_host_net) {
    GridService.create!(
      name: 'net_app',
      grid: grid,
      image_name: 'my/app:latest',
      net: 'host'
    )
  }

  it 'creates default network for all grids' do
    grid
    another_grid
    DefaultNetwork.up
    expect(grid.networks.count).to eq(1)
    expect(grid.networks.first.name).to eq('kontena')
    expect(another_grid.networks.count).to eq(1)
    expect(another_grid.networks.first.name).to eq('kontena')
  end

  it 'attaches default network for all services' do
    grid
    another_grid
    DefaultNetwork.up
    GridService.each do |service|
      expect(service.networks.count).to eq(1)
      expect(service.networks.first.name).to eq('kontena')
    end
  end

  it 'doesn\'t attach overlay to service with host net' do
    s = service_with_host_net
    DefaultNetwork.up
    expect(s.networks.count).to eq(0)
  end
end
