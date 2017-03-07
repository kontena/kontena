require "kontena/cli/vpn/create_command"

describe Kontena::Cli::Vpn::CreateCommand do

  include ClientHelpers

  let(:subject) { described_class.new(File.basename($0)) }

  describe '#execute' do
    it 'should abort if vpn already exists' do
      expect(client).to receive(:get).with("stacks/test-grid/vpn").and_return({})

      expect {
        subject.execute
      }.to exit_with_error
    end
  end

  describe '#find_node' do
    it 'should abort if no online nodes exists' do
      expect(client).to receive(:get).with("grids/test-grid/nodes").and_return(
        {
          'nodes' => [
            {'connected' => false},
            {'connected' => false, 'public_ip' => '1.2.3.4'}
          ]
        })

      expect {
        subject.find_node(token, nil)
      }.to exit_with_error
    end

    it 'should return first online node with public ip' do
      expect(client).to receive(:get).with("grids/test-grid/nodes").and_return(
        {
          'nodes' => [
            {'connected' => true},
            {'connected' => true, 'public_ip' => '1.2.3.4'}
          ]
        })

      node = subject.find_node(token, nil)
      expect(node['public_ip']).to eq('1.2.3.4')
    end

    it 'should return preferred node' do
      expect(client).to receive(:get).with("grids/test-grid/nodes").and_return(
        {
          'nodes' => [
            {'connected' => true},
            {'name' => 'preferred', 'connected' => true, 'public_ip' => '1.2.3.4'}
          ]
        })

      node = subject.find_node(token, 'preferred')
      expect(node['name']).to eq('preferred')
    end

    it 'should abort if no online nodes exists' do
      expect(client).to receive(:get).with("grids/test-grid/nodes").and_return(
        {
          'nodes' => [
            {'connected' => true},
            {'name' => 'preferred', 'connected' => true, 'public_ip' => '1.2.3.4'}
          ]
        })

      expect {
        subject.find_node(token, 'foobar')
      }.to exit_with_error
    end

  end

  describe '#node_vpn_ip' do
    it 'return ip when set' do
      allow(subject).to receive(:ip).and_return('1.2.3.4')

      expect(subject.node_vpn_ip(nil)).to eq('1.2.3.4')
    end

    it 'return public ip when set on node' do
      allow(subject).to receive(:ip).and_return(nil)
      node = {
        'public_ip' => '8.8.8.8',
        'private_ip' => '10.1.1.2'
      }
      expect(subject.node_vpn_ip(node)).to eq('8.8.8.8')
    end

    it 'return private ip when public not set on node' do
      allow(subject).to receive(:ip).and_return(nil)
      node = {
        'private_ip' => '10.1.1.2'
      }
      expect(subject.node_vpn_ip(node)).to eq('10.1.1.2')
    end

    it 'return private on vagrant nodes' do
      allow(subject).to receive(:ip).and_return(nil)
      node = {
        'public_ip' => '8.8.8.8',
        'private_ip' => '10.1.1.2',
        'labels' => ['provider=vagrant']
      }
      expect(subject.node_vpn_ip(node)).to eq('10.1.1.2')
    end
  end
end
