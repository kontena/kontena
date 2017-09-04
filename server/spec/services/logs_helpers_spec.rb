
describe LogsHelpers do
  class Subject
    include LogsHelpers

    def render(template, locals)
      locals
    end
  end

  let(:subject) do
    Subject.new
  end

  let(:grid) do
    Grid.create!(name: 'test-grid')
  end

  let(:nodes) do
    {
      node1: grid.create_node!('node-1', node_id: SecureRandom.uuid),

    }
  end

  let(:services) do
    {
      foo: grid.grid_services.create!(name: 'foo', image_name: 'foo/bar'),
      bar: grid.grid_services.create!(name: 'bar', image_name: 'bar/foo'),
    }
  end

  let(:containers) do
    {
      foo_container1: services[:foo].containers.create!(name: 'foo-1', host_node: nodes[:node1], container_id: 'aaa'),
      foo_container2: services[:foo].containers.create!(name: 'foo-2', host_node: nodes[:node1], container_id: 'bbb'),

      bar_container1: services[:bar].containers.create!(name: 'bar-1', host_node: nodes[:node1], container_id: 'ccc'),
    }
  end

  context 'when fetching logs' do
    before do
      stub_const('LogsHelpers::LOGS_LIMIT_DEFAULT', 10)
      stub_const('LogsHelpers::LOGS_LIMIT_MAX', 20)

      container = containers[:bar_container1]
      @logs = (1..100).map do |i|
        container.container_logs.create!(
          data: "log #{i}",
          type: 'stdout',
          created_at: (100 - i).seconds.ago,
          grid: grid,
          grid_service: container.grid_service,
        )
      end

      expect(subject).to receive(:render).with('container_logs/index', locals: hash_including(:logs)) { |template, locals:| locals[:logs] }
    end

    it 'returns the default number of recent lines in id order' do
      logs = subject.render_container_logs({}, grid.container_logs)

      expect(logs).to be_a(Array)
      expect(logs).to eq @logs[-10, 10]
    end

    it 'returns lines since a given time' do
      since = 10.seconds.ago

      logs = subject.render_container_logs({ 'since' => since.to_s}, grid.container_logs)

      expect(logs).to be_a(Array)
      expect(logs).to eq @logs[-10..-1]
    end

    it 'returns up to limit lines from a given id' do
      logs = subject.render_container_logs({ 'from' => @logs[-20]['id'], 'limit' => 5}, grid.container_logs)

      expect(logs).to be_a(Array)
      expect(logs).to eq @logs[-19, 5]
    end
  end

  context 'when following logs' do
    let(:streamer) do
      double("streamer")
    end

    before do
      stub_const('LogsHelpers::LOGS_LIMIT_DEFAULT', 10)
      stub_const('LogsHelpers::LOGS_LIMIT_MAX', 20)
      stub_const('LogsHelpers::LOGS_STREAM_CHUNK', 20)

      allow(subject).to receive(:sleep)
    end

    def mock_streamloop
      @stream = []
      allow(subject).to receive(:stream).with(loop: true) do |&arg|
        while (yield) do
          arg.call streamer
        end
      end
      allow(streamer).to receive(:<<) { |out| @stream << out }
      allow(subject).to receive(:render).with('container_logs/_container_log', locals: hash_including(:log)) { |template, locals:| locals[:log] }
    end

    it 'starts with the limit most recent lines' do
      expect(subject).to receive(:sleep) { }

      container = containers[:bar_container1]
      @logs = (1..50).map do |i|
        container.container_logs.create!(
          data: "log #{i}",
          type: 'stdout',
          created_at: (100 - i).seconds.ago,
          grid: grid,
          grid_service: container.grid_service,
        )
      end

      loops = 0
      mock_streamloop { (loops += 1) <= 2 }

      subject.render_container_logs({ 'follow' => 1}, grid.container_logs)

      expect(@stream).to eq @logs[-10, 10] + [" "]
    end

    it 'handles multiple batches of logs' do
      container = containers[:bar_container1]
      loops = 0
      stream = []

      mock_streamloop {
        case loops += 1
        when 1
          stream.concat((1..10).map { |i|
            container.container_logs.create!(
              data: "log #{i}",
              type: 'stdout',
              created_at: (50 - i).seconds.ago,
              grid: grid,
              grid_service: container.grid_service,
            )
          })
        when 2
          stream << " "
        when 3
          stream.concat((11..50).map { |i|
            container.container_logs.create!(
              data: "log #{i}",
              type: 'stdout',
              created_at: (50 - i).seconds.ago,
              grid: grid,
              grid_service: container.grid_service,
            )
          })
        when 4
          # still processing LIMIT_MAX from previous batch
          true
        when 5
          stream << " "
        else
          false
        end
      }

      subject.render_container_logs({ 'follow' => 1}, grid.container_logs)

      expect(@stream).to eq stream
      expect(@stream[-1]).to eq " "
      expect(@stream[-2]['data']).to eq "log 50"
      expect(@stream[0]['data']).to eq "log 1"
      expect(@stream.size).to eq 52
    end
  end
end
