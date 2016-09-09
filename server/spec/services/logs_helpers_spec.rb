require_relative '../spec_helper'

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
      node1: grid.host_nodes.create!(name: 'node-1', node_id: SecureRandom.uuid),

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
  end
end
