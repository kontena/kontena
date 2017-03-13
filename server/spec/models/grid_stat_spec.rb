
describe GridStat do
  it { should be_timestamped_document }
  it { should have_fields(:running_containers, :not_running_containers)}

  let :grid do
    Grid.create(token: 'random-token')
  end

  let :container1 do
    Container.create(grid: grid)
  end

  let :container2 do
    Container.create(grid: grid)
  end

  context '.grid_memory_usage' do
    before :each do
      i = 0
      @current_time = Time.now
      5.times do
        allow(Time).to receive(:now) { @current_time - (i* 60 * 60 * 24) } # first 5 days ago, then 4 days ago etc
        ContainerStat.create(grid: grid, container: container1, memory: { 'usage' => 1})
        ContainerStat.create(grid: grid, container: container2, memory: { 'usage' => 1})
        i += 1
      end
      allow(Time).to receive(:now).and_call_original
    end

    it 'returns correct amount of stats' do
      stat = GridStat.memory_usage(grid.id, DateTime.now - 4.days, DateTime.now) # opt out first container_stat
      expect(stat.length).to eq(4)

      stat = GridStat.memory_usage(grid.id, DateTime.now - 5.days, DateTime.now - 1.day) # opt out last container_stat
      expect(stat.length).to eq(4)
    end

    it 'sums container memory usages' do
      stat = GridStat.memory_usage(grid.id, DateTime.now - 5.days, DateTime.now)
      expect(stat.first['memory']).to eq(2)
    end

    it 'formats correct date to _id field' do
      first_creation_time = (@current_time - 4.days).utc
      stat = GridStat.memory_usage(grid.id, DateTime.now - 5.days, DateTime.now)
      expect(stat.first['_id']['year']).to eq(first_creation_time.year)
      expect(stat.first['_id']['month']).to eq(first_creation_time.month)
      expect(stat.first['_id']['day']).to eq(first_creation_time.day)
      expect(stat.first['_id']['hour']).to eq(first_creation_time.hour)
      expect(stat.first['_id']['minute']).to eq(first_creation_time.min)
    end

  end
end
