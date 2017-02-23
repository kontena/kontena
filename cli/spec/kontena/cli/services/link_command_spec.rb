require_relative "../../../spec_helper"
require "kontena/cli/services/link_command"

describe Kontena::Cli::Services::LinkCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'links' => []
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

    it 'aborts if service is already linked' do
      allow(client).to receive(:get).and_return({
        'links' => [
          {'alias' => 'service-b', 'id' => "grid/null/service-b"}
        ]
      })
      expect {
        subject.run(['service-a', 'service-b'])
      }.to exit_with_error
    end

    it 'sends link to master' do
      expect(client).to receive(:put).with(
        'services/test-grid/null/service-a', {links: [{name: 'null/service-b', alias: 'service-b'}]}
      )
      subject.run(['service-a', 'service-b'])
    end
  end
end
