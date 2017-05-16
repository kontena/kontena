require "kontena/cli/containers/list_command"

describe Kontena::Cli::Containers::ListCommand do
  include ClientHelpers

  context "for a single container with logs" do

    it "fetches containers" do
      expect(client).to receive(:get).with('containers/test-grid?').and_return({'containers' => []})

      subject.run([])
    end
  end

  context '#longest_string_in_array' do
    expect(described_class.new('').longest_string_in_array(['a', 'bcd', 'ef'])).to eq 'bcd'
  end
end
