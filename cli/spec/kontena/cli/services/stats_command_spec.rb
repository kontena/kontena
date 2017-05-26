require "kontena/cli/services/stats_command"

describe Kontena::Cli::Services::StatsCommand do
  describe "MEM_MAX_LIMITS" do
    let(:subject) { described_class.const_get(:MEM_MAX_LIMITS) }

    context 'first' do
      it 'is 64 bits' do
        expect(subject.first).to eq 2**64
        expect(subject.first).to eq 1.8446744073709552e+19
      end
    end

    context 'last' do
      it 'is 9223372036854771712' do
        expect(subject.last).to eq 0x7FFFFFFFFFFFF000
        expect(subject.last).to eq 9.223372036854772e+18
      end
    end
  end
end

