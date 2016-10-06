require_relative "../../../spec_helper"
require "kontena/cli/services/unlink_command"

describe Kontena::Cli::Services::UnlinkCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'links' => [
          {'alias' => 'service-b', 'grid_service_id' => "grid/service-b"}
        ]
      })
    end

    it 'requires api url' do
      expect(subject.class.requires_current_master).to be_truthy
      subject.run(['service-a', 'service-b'])
    end

    it 'requires token' do
      expect(subject.class.requires_current_master_token).to be_truthy
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
        'services/test-grid/service-a', {links: []}
      )
      subject.run(['service-a', 'service-b'])
    end
  end
end
