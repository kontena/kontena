require_relative '../spec_helper'

describe RpcClient do

  let(:node_id) { SecureRandom.hex(32) }
  let(:subject) { RpcClient.new(node_id, 1) }
  let(:channel) { RpcClient::RPC_CHANNEL }

  def publish_response(id, response)
    MongoPubsub.publish(channel, {message: [1, id, nil, response]})
  end

  def publish_error(id, error)
    MongoPubsub.publish(channel, {message: [1, id, error, nil]})
  end

  def fake_server(&block)
    Thread.new {
      MongoPubsub.subscribe(channel) do |sub|
        sub.on_message do |resp|
          if resp['type'] == 'request'
            yield(resp)
            sub.terminate
          end
        end
      end
    }
    sleep 0.1
  end

  describe '#request' do
    it 'returns a result from rpc server' do
      fake_server {|resp|
        response = resp['message'][3]
        response.unshift(resp['message'][2])
        publish_response(resp['message'][1], response)
      }
      resp = subject.request('/hello/service', :foo, :bar)
      expect(resp).to eq(['/hello/service', :foo, :bar])
    end

    it 'raises error from rpc server' do
      fake_server {|resp|
        response = resp['message'][3]
        response.unshift(resp['message'][2])
        publish_error(resp['message'][1], 'error!')
      }
      expect {
        subject.request('/hello/service', :foo, :bar)
      }.to raise_error(RpcClient::Error)
    end
  end
end