require_relative "../../../spec_helper"
require "kontena/cli/services/logs_command"

describe Kontena::Cli::Services::LogsCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'logs' => []
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

    it 'requests logs from master' do
      expect(client).to receive(:get).with(
        'services/test-grid/null/service-a/container_logs', {limit: 100}
      )
      subject.run(['service-a'])
    end

    context 'when passing instance option ' do
      it 'adds it to query params' do
        expect(client).to receive(:get).with(
          'services/test-grid/null/service-a/container_logs', {instance: '1', limit: 100}
        )
        subject.run(['-i', '1', 'service-a'])
      end
    end
  end
end
