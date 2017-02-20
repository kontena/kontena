require_relative '../spec_helper'

describe GridSchedulerJob, celluloid: true do
  before(:each) { DistributedLock.delete_all }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) do
    GridService.create!(
      name: 'redis',
      image_name: 'redis:latest',
      grid: grid,
      state: 'running',
      created_at: 5.minutes.ago,
      updated_at: 4.minutes.ago
    )
  end
end
