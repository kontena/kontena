require_relative '../spec_helper'

describe RpcClient do

  let(:wharfie_id) do
    SecureRandom.hex(32)
  end

  let(:subject) do
    RpcClient.new(wharfie_id)
  end

  def start_rpc_server(error = nil)
    @rpc_server = Thread.new {
      wharfie_channel = RpcClient::REDIS_CHANNEL
      $redis_sub.with do |sub|
        sub.subscribe(wharfie_channel) do |on|
          on.message do |_, msg|
            sleep 0.01
            resp = MessagePack.unpack(msg) rescue nil
            if resp['type'] == 'request'
              if resp['message'] && resp['message'][0] == 0 && resp['message'].size == 4
                $redis.with do |redis|
                  response = nil
                  if error.nil?
                    response = resp['message'][3]
                    response.unshift(resp['message'][2])
                  end
                  redis.publish(wharfie_channel, MessagePack.dump([1, resp['message'][1], error, response]))
                end
              end
            end
          end
        end
      end
    }
    sleep 0.01
    @rpc_server
  end

  def kill_rpc_server
    @rpc_server.kill if @rpc_server
  end

  after(:each) do
    kill_rpc_server
  end

  describe '#request' do

    it 'returns a result from rpc server' do
      start_rpc_server
      resp = subject.request('/hello/service', :foo, :bar)
      expect(resp).to eq(['/hello/service', 'foo', 'bar'])
    end

    it 'raises error from rpc server' do
      start_rpc_server('test error')
      expect {
        subject.request('/hello/service', :foo, :bar)
      }.to raise_error(RpcClient::Error)
    end
  end
end