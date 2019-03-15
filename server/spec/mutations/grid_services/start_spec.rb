describe GridServices::Start do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8', state: 'stopped') }
  let(:subject) { described_class.new(grid_service: service) }

  it 'sets service state to running' do
    expect{subject.run!}.to change{service.reload.state}.from('stopped').to('running')
  end

  it 'does not change service revision' do
    expect{subject.run!}.to_not change{service.reload.revision}
  end

  it 'creates deploy' do
    expect{subject.run!}.to change{service.reload.deploying?}.from(false).to(true)
  end

  it 'returns deploy' do
    expect(subject.run!).to be_a GridServiceDeploy
  end
end
