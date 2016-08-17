require_relative "../../../spec_helper"
require "kontena/cli/grid_options"
require "kontena/cli/services/update_command"

describe Kontena::Cli::Services::UpdateCommand do

  include ClientHelpers

  describe '#execute' do

    before(:each) do
      allow(subject).to receive(:update_service).and_return({})
    end

    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['service'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).once
      subject.run(['service'])
    end

    it 'sends update command' do
      expect(subject).to receive(:update_service).with(duck_type(:access_token), 'service', {privileged: false})
      subject.run(['service'])
    end

    it 'sends --cap-add' do
      expect(subject).to receive(:update_service).with(duck_type(:access_token), 'service', hash_including(cap_add: ['NET_ADMIN']))
      subject.run(['--cap-add', 'NET_ADMIN', 'service'])
    end

    it 'sends --cap-drop' do
      expect(subject).to receive(:update_service).with(duck_type(:access_token), 'service', hash_including(cap_drop: ['MKNOD']))
      subject.run(['--cap-drop', 'MKNOD', 'service'])
    end

    it 'sends --log-driver' do
      expect(subject).to receive(:update_service).with(duck_type(:access_token), 'service', hash_including(log_driver: 'syslog'))
      subject.run(['--log-driver', 'syslog', 'service'])
    end

    it 'sends --log-opt' do
      expect(subject).to receive(:update_service).with(
        duck_type(:access_token), 'service', hash_including(log_opts: {
          'gelf-address'  => 'udp://log_forwarder-logstash_internal:12201'
        })
      )
      subject.run([
        '--log-opt', 'gelf-address=udp://log_forwarder-logstash_internal:12201', 'service'
      ])
    end
  end
end
