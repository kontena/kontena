require_relative "../../../spec_helper"
require "kontena/cli/services/unlink_command"

describe Kontena::Cli::Services::UnlinkCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'links' => [
          {'alias' => 'service-b', 'id' => "test-grid/null/service-b", 'name' => 'service-b'}
        ]
      })
    end

    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['service-a', 'service-b'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['service-a', 'service-b'])
    end

    it 'aborts if service is not linked' do
      allow(client).to receive(:get).and_return({
        'links' => []
      })
      expect {
        subject.run(['service-a', 'service-b'])
      }.to raise_error(SystemExit)
    end

    it 'sends link to master' do
      expect(client).to receive(:put).with(
        'services/test-grid/null/service-a', {links: []}
      )
      subject.run(['service-a', 'service-b'])
    end
  end
end
