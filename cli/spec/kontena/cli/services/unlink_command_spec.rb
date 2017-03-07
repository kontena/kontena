require "kontena/cli/services/unlink_command"

describe Kontena::Cli::Services::UnlinkCommand do

  include ClientHelpers

  describe '#execute' do
    it 'aborts if service is not linked' do
      expect(client).to receive(:get).with('services/test-grid/null/service-a').and_return({
        'links' => []
      })
      expect {
        subject.run(['service-a', 'service-b'])
      }.to exit_with_error
    end

    it 'sends link to master' do
      expect(client).to receive(:get).with('services/test-grid/null/service-a').and_return({
        'links' => [
          {'alias' => 'service-b', 'id' => "test-grid/null/service-b", 'name' => 'service-b'}
        ]
      })
      expect(client).to receive(:put).with(
        'services/test-grid/null/service-a', {links: []}
      )
      subject.run(['service-a', 'service-b'])
    end
  end
end
