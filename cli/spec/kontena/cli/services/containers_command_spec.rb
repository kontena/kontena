require_relative "../../../spec_helper"
require "kontena/cli/services/containers_command"

describe Kontena::Cli::Services::ContainersCommand do

  include ClientHelpers

  describe '#execute' do

    before(:each) do
      allow(client).to receive(:get).and_return({
        'containers' => []
      })
    end

    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['service-a'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['service-a'])
    end

    it 'to not throw on missing "overlay_cidr" property' do
      allow(client).to receive(:get).and_return({
        'containers' => [
          {'id' => "service-a-id", 'node' => {'public_ip' => ""}}
        ]
      })
      expect {
        subject.run(['service-a'])
      }.to_not raise_error(NoMethodError)
    end

    it 'to not throw on nil "overlay_cidr" property' do
      allow(client).to receive(:get).and_return({
        'containers' => [
          {'id' => "service-a-id", 'node' => {'public_ip' => ""}, 'overlay_cidr' => nil}
        ]
      })
      expect {
        subject.run(['service-a'])
      }.to_not raise_error(NoMethodError)
    end
  end
end
