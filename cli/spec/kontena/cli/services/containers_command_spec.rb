require "kontena/cli/services/containers_command"

describe Kontena::Cli::Services::ContainersCommand do

  include ClientHelpers

  describe '#execute' do
    it 'to not throw on missing "overlay_cidr" property' do
      allow(client).to receive(:get).and_return({
        'containers' => [
          {'id' => "service-a-id", 'node' => {'public_ip' => ""}}
        ]
      })
      expect {
        subject.run(['service-a'])
      }.to_not raise_error
    end

    it 'to not throw on nil "overlay_cidr" property' do
      allow(client).to receive(:get).and_return({
        'containers' => [
          {'id' => "service-a-id", 'node' => {'public_ip' => ""}, 'overlay_cidr' => nil}
        ]
      })
      expect {
        subject.run(['service-a'])
      }.to_not raise_error
    end
  end
end
