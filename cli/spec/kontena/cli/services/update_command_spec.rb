require "kontena/cli/grid_options"
require "kontena/cli/services/update_command"

describe Kontena::Cli::Services::UpdateCommand do

  include ClientHelpers

  describe '#execute' do

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

    context 'health check' do
      it 'sends --health-check-port' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            port: '8080'
          })
        )
        subject.run([
          '--health-check-port', '8080', 'service'
        ])
      end

      it 'sends --health-check-port as nil if none given' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            port: nil
          })
        )
        subject.run([
          '--health-check-port', 'none', 'service'
        ])
      end

      it 'sends --health-check-protocol' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            protocol: 'tcp'
          })
        )
        subject.run([
          '--health-check-protocol', 'tcp', 'service'
        ])
      end

      it 'sends --health-check-protocol as nil if none given' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            protocol: nil
          })
        )
        subject.run([
          '--health-check-protocol', 'none', 'service'
        ])
      end

      it 'sends --health-check-timeout' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            timeout: '30'
          })
        )
        subject.run([
          '--health-check-timeout', '30', 'service'
        ])
      end

      it 'sends --health-check-uri' do
        expect(subject).to receive(:update_service).with(
          duck_type(:access_token), 'service', hash_including(health_check: {
            uri: '/health'
          })
        )
        subject.run([
          '--health-check-uri', '/health', 'service'
        ])
      end
    end
  end
end
