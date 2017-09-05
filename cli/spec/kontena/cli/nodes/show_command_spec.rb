require 'kontena/cli/nodes/show_command'

describe Kontena::Cli::Nodes::ShowCommand do
  include ClientHelpers
  include OutputHelpers
  include FixturesHelpers

  let(:subject) { described_class.new("kontena") }

  let(:node) {
    JSON.load(fixture('api/node.json'))
  }

  before do
    allow(client).to receive(:get).with('nodes/test-grid/core-01').and_return(node)
  end

  it "outputs the node info" do
    expect{subject.run(['core-01'])}.to output_lines([
      'development/core-01:',
      '  id: XI4K:NPOL:EQJ4:S4V7:EN3B:DHC5:KZJD:F3U2:PCAN:46EV:IO4A:63S5',
      '  agent version: 1.4.0.dev',
      '  docker version: 1.12.6',
      '  connected: yes',
      '  last connect: 2017-07-04T08:36:02.235Z',
      '  last seen: 2017-07-04T08:36:02.280Z',
      '  availability: active',
      '  public ip: 91.150.10.190',
      '  private ip: 192.168.66.101',
      '  overlay ip: 10.81.0.1',
      '  os: Container Linux by CoreOS 1409.5.0 (Ladybug)',
      '  kernel: 4.11.6-coreos-r1',
      '  drivers:',
      '    storage: overlay',
      '    volume: local',
      '  initial node: yes',
      '  labels:',
      '    - test',
      '  stats:',
      '    cpus: 1',
      '    load: 1.49 0.34 0.11',
      '    memory: 0.39 of 0.97 GB',
      '    filesystem:',
      '      - /var/lib/docker: 2.89 of 15.57 GB',
    ])
  end

  it 'does not fail with missing fs stats' do
    node_info = node
    node_info.delete('resource_usage')
    allow(client).to receive(:get).with('nodes/test-grid/core-01').and_return(node_info)

    expect{subject.run(['core-01'])}.to output_lines([
      'development/core-01:',
      '  id: XI4K:NPOL:EQJ4:S4V7:EN3B:DHC5:KZJD:F3U2:PCAN:46EV:IO4A:63S5',
      '  agent version: 1.4.0.dev',
      '  docker version: 1.12.6',
      '  connected: yes',
      '  last connect: 2017-07-04T08:36:02.235Z',
      '  last seen: 2017-07-04T08:36:02.280Z',
      '  availability: active',
      '  public ip: 91.150.10.190',
      '  private ip: 192.168.66.101',
      '  overlay ip: 10.81.0.1',
      '  os: Container Linux by CoreOS 1409.5.0 (Ladybug)',
      '  kernel: 4.11.6-coreos-r1',
      '  drivers:',
      '    storage: overlay',
      '    volume: local',
      '  initial node: yes',
      '  labels:',
      '    - test',
      '  stats:',
      '    cpus: 1'
    ])
  end
end
