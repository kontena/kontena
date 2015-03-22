require_relative '../../spec_helper'

describe Docker::ImagePuller do

  let(:client) do
    spy(:client)
  end

  let(:host_node) do
    node = HostNode.create!(node_id: SecureRandom.uuid)
    allow(node).to receive(:rpc_client).and_return(client)
    node
  end

  let(:subject) do
    described_class.new(host_node)
  end

  let(:image_json) do
    {
        'Id' => SecureRandom.uuid,
        'Size' => 100000,
        'Config' => {
            'ExposedPorts' => {
                '3306/tcp' => []
            }
        }
    }
  end

  describe '#pull_image' do
    it 'sends image pull request to agent' do
      expect(client).to receive(:request).with('/images/create', {fromImage: 'new_redis:2.8'}, nil)
      allow(client).to receive(:request).with('/images/show', 'new_redis:2.8').and_return(image_json)
      subject.pull_image('new_redis:2.8')
    end

    it 'creates a new image if it does not exist' do
      allow(client).to receive(:request).with('/images/create', {fromImage: 'redis:2.8'}, nil)
      allow(client).to receive(:request).with('/images/show', 'redis:2.8').and_return(image_json)
      expect {
        subject.pull_image('redis:2.8')
      }.to change{ Image.count }.by(1)
    end

    it 'parses exposed ports from agent response' do
      allow(client).to receive(:request).with('/images/create', {fromImage: 'redis:2.8'}, nil)
      allow(client).to receive(:request).with('/images/show', 'redis:2.8').and_return(image_json)
      subject.pull_image('redis:2.8')

      image = Image.find_by(name: 'redis:2.8')
      expect(image.exposed_ports).to eq([{'port' => '3306', 'protocol' => 'tcp'}])
    end

    it 'does not create new image if it exists' do
      Image.create(name: 'redis:2.8')
      allow(client).to receive(:request).with('/images/create', {fromImage: 'redis:2.8'}, nil)
      allow(client).to receive(:request).with('/images/show', 'redis:2.8').and_return(image_json)
      expect {
        subject.pull_image('redis:2.8')
      }.to change{ Image.count }.by(0)
    end
  end
end