require 'kontena/cli/volumes/create_command'

describe Kontena::Cli::Volumes::CreateCommand do
  let(:subject) { described_class.new("kontena") }

  describe '#parse_driver_opts' do
    it 'parses driver opts' do
      allow(subject).to receive(:driver_opt_list).and_return([
        'foo=bar',
        'o=addr=XXX.XXX.XXX.XXX,rw,nfsvers=3,nolock,proto=udp,port=2049'
      ])
      opts = subject.parse_driver_opts
      expect(opts['foo']).to eq('bar')
      expect(opts['o']).to eq('addr=XXX.XXX.XXX.XXX,rw,nfsvers=3,nolock,proto=udp,port=2049')
    end
  end
end