require "kontena/cli/grid_options"
require "kontena/cli/services/secrets/unlink_command"

describe Kontena::Cli::Services::Secrets::UnlinkCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires service as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'requires secret as param' do
      expect {
        subject.run(['service'])
      }.to raise_error(Clamp::UsageError)
    end

    it 'removes secret to existing list' do
      original = {
        'secrets' => [
          {'secret' => 'FOO', 'name' => 'BAR', 'type' => 'env'},
          {'secret' => 'BAR', 'name' => 'BAZ', 'type' => 'env'}
        ]
      }
      data = {
        secrets: [
          {'secret' => 'BAR', 'name' => 'BAZ', 'type' => 'env'}
        ]
      }
      expect(client).to receive(:get).with("services/test-grid/null/mymy").and_return(original)
      expect(client).to receive(:put).with("services/test-grid/null/mymy", data)
      subject.run(['mymy', 'FOO:BAR:env'])
    end
  end
end
