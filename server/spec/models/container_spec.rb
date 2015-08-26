require_relative '../spec_helper'

describe Container do
  it { should be_timestamped_document }
  it { should have_fields(
        :container_id, :name, :driver,
        :exec_driver, :image, :overlay_cidr).of_type(String) }
  it { should have_fields(:env, :volumes).of_type(Array) }
  it { should have_fields(:network_settings, :state).of_type(Hash) }
  it { should have_fields(:finished_at, :started_at).of_type(Time) }

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }
  it { should have_index_for(container_id: 1) }
  it { should have_index_for(state: 1) }
  it { should have_index_for(grid_id: 1, overlay_cidr: 1)
        .with_options(sparse: true, unique: true) }

  describe '#status' do
    it 'returns deleted when deleted_at timestamp is set' do
      subject.deleted_at = Time.now.utc
      expect(subject.status).to eq('deleted')
    end

    it 'returns unknown if updated_at timestamp is far enough in the past' do
      subject.updated_at = Time.now.utc - 3.minutes
      expect(subject.status).to eq('unknown')
    end

    it 'returns paused if docker state is paused' do
      subject.updated_at = Time.now
      subject.state['paused'] = true
      expect(subject.status).to eq('paused')
    end

    it 'returns stopped if docker state is stopped' do
      subject.updated_at = Time.now
      subject.state['stopped'] = true
      expect(subject.status).to eq('stopped')
    end

    it 'returns running if docker state is running' do
      subject.updated_at = Time.now
      subject.state['running'] = true
      expect(subject.status).to eq('running')
    end

    it 'returns restarting if docker state is restarting' do
      subject.updated_at = Time.now
      subject.state['restarting'] = true
      expect(subject.status).to eq('restarting')
    end

    it 'returns oom_killed if docker state is oom_killed' do
      subject.updated_at = Time.now
      subject.state['oom_killed'] = true
      expect(subject.status).to eq('oom_killed')
    end

    it 'returns stopped otherwise' do
      subject.updated_at = Time.now
      expect(subject.status).to eq('stopped')
    end
  end

  describe '#parse_docker_network_settings' do
    let(:docker_data) do
      {
        "Bridge" => "docker0",
        "Gateway" => "172.17.42.1",
        "IPAddress" => "172.17.0.26",
        "IPPrefixLen" => 16,
        "MacAddress" => "02:42:ac:11:00:1a",
        "PortMapping" => nil,
        "Ports" => {
          "6379/tcp" => [
            {
              "HostIp" => "0.0.0.0",
              "HostPort" => "6379"
            }
          ]
        }
      }
    end

    it 'parses ports correctly' do
      res = subject.parse_docker_network_settings(docker_data)
      expect(res[:ports]).to eq(
        "6379/tcp" => [
          {
            node_ip: "0.0.0.0",
            node_port: 6379
          }
        ]
      )
    end
  end
end
