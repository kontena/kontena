require_relative '../spec_helper'
require_relative '../../db/migrations/19_volume_migration'

describe VolumeMigration do

  let(:grid) {
    Grid.create!(name: 'foo')
  }

  let(:service_with_bind_mount) {
    GridService.create!(
      name: 'app',
      grid: grid,
      image_name: 'my/app:latest',
      volumes: ['/proc:/host/proc']
    )
  }

  it 'create service_volume for bind mount' do
    s = service_with_bind_mount
    VolumeMigration.up
    s.reload
    expect(s.service_volumes.count).to eq(1)
    expect(s.service_volumes.first.path).to eq('/host/proc')
    expect(s.service_volumes.first.volume).to be_nil
    expect(s.service_volumes.first.bind_mount).to eq('/proc')
  end

  let(:service_with_anon_vol) {
    GridService.create!(
      name: 'app',
      grid: grid,
      image_name: 'my/app:latest',
      volumes: ['/data']
    )
  }

  it 'create service_volume for anon vol' do
    s = service_with_anon_vol
    VolumeMigration.up
    s.reload
    expect(s.service_volumes.count).to eq(1)
    expect(s.service_volumes.first.path).to eq('/data')
    expect(s.service_volumes.first.volume).to be_nil
    expect(s.service_volumes.first.bind_mount).to be_nil
  end

  let(:service_with_named_vol) {
    GridService.create!(
      name: 'app',
      grid: grid,
      image_name: 'my/app:latest',
      volumes: ['myVol:/data']
    )
  }

  it 'create service_volume for named vol' do
    s = service_with_named_vol
    expect {
      VolumeMigration.up
    }.to change {Volume.count}.by (1)
    s.reload
    volume = Volume.first
    expect(s.service_volumes.count).to eq(1)
    expect(s.service_volumes.first.path).to eq('/data')
    expect(s.service_volumes.first.volume).to eq(volume)
    expect(s.service_volumes.first.bind_mount).to be_nil
    expect(volume.name).to eq('myVol')
    expect(volume.driver).to eq('local')
    expect(volume.scope).to eq('grid')
  end

end
