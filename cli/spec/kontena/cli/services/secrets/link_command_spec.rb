require "kontena/cli/services/secrets/link_command"

describe Kontena::Cli::Services::Secrets::LinkCommand do

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

    it 'sends secrets to master' do
      data = {
        secrets: [
          {secret: 'MY_PASSWORD', name: 'PASSWORD', type: 'env'}
        ]
      }
      allow(client).to receive(:get).with("services/test-grid/null/foo").and_return({
        'secrets' => []
      })
      expect(client).to receive(:put).with("services/test-grid/null/foo", data)
      subject.run(['foo', 'MY_PASSWORD:PASSWORD:env'])
    end

    it 'appends secret to existing list' do
      original = {
        'secrets' => [
          {'secret' => 'FOO', 'name' => 'BAR', 'type' => 'env'}
        ]
      }
      data = {
        secrets: [
          {'secret' => 'FOO', 'name' => 'BAR', 'type' => 'env'},
          {secret: 'MY_PASSWORD', name: 'PASSWORD', type: 'env'}
        ]
      }
      allow(client).to receive(:get).with("services/test-grid/null/foo").and_return(original)
      expect(client).to receive(:put).with("services/test-grid/null/foo", data)
      subject.run(['foo', 'MY_PASSWORD:PASSWORD:env'])
    end
  end
end
