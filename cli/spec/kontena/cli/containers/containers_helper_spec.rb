require "kontena/cli/containers/containers_helper"

describe Kontena::Cli::Containers::ContainersHelper do
  let(:subject) do
    Class.new { include Kontena::Cli::Containers::ContainersHelper }.new
  end

  describe '#build_command' do
    it 'parses commands correctly' do
      expect(subject.build_command(['echo $ID'])).to eq('echo $ID')
      expect(subject.build_command(['echo', 'ID', '$ID'])).to eq('echo ID $ID')
      expect(subject.build_command(['echo', 'ID: $ID'])).to eq('echo "ID: $ID"')
      expect(subject.build_command(['echo', '{"ID": "123"}'])).to eq('echo "{\\"ID\\": \\"123\\"}"')
    end
  end
end
