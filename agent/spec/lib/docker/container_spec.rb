require_relative '../../spec_helper'

describe Docker::Container do

  let(:subject) do
    Docker::Container.new()
  end

  before(:each) do
    allow(subject).to receive(:json).and_return({
      'Config' => {
        'Labels' => {
          'io.kontena.container.name' => 'foo-1'
        }
      },
      'State' => {
        'Running' => true
      },
      'HostConfig' => {
        'Devices' => nil,
        'RestartPolicy' => {'Name' => 'always'}
      }
    })
  end

  describe '#labels' do
    it 'returns labels hash' do
      expect(subject.labels).to include('io.kontena.container.name' => 'foo-1')
    end
  end

  describe '#state' do
    it 'returns State hash' do
      expect(subject.state).to include('Running' => true)
    end
  end

  describe '#host_config' do
    it 'returns HostConfig hash' do
      expect(subject.host_config).to include('Devices' => nil)
    end
  end

  describe '#restart_policy' do
    it 'returns HostConfig.RestartPolicy hash' do
      expect(subject.restart_policy).to include('Name' => 'always')
    end
  end
end
