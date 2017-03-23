describe Kontena::Helpers::WaitHelper do

  let(:klass) {
    Class.new { include Kontena::Helpers::WaitHelper }
  }

  let(:subject) {
    klass.new
  }

  # fake clock
  before do
    @time_elapsed = 0.0

    allow(subject).to receive(:_wait_now) { @time_elapsed }
    allow(subject).to receive(:sleep) { |dt| @time_elapsed += dt }
  end

  describe 'wait' do
    it 'returns true immediately' do
      expect(subject).not_to receive(:sleep)

      value = subject.wait_until { true }

      expect(value).to be_truthy
    end

    it 'sleeps between retries and logs debug' do
      expect(subject).to receive(:debug).with('waiting 0.5s of 2.0s until: something that is true the second time')
      expect(subject).to receive(:debug).with('waited 0.5s until: something that is true the second time yielded true')

      @loop = 0
      value = subject.wait_until("something that is true the second time", timeout: 2) { (@loop += 1) > 1 }

      expect(value).to be_truthy
      expect(@loop).to eq 2
      expect(@time_elapsed).to eq(0.5)
    end

    it 'sleeps between retries before timing out' do
      value = subject.wait_until(timeout: 2) { false }

      expect(value).to be_falsey
      expect(@time_elapsed).to eq(2.0)
    end

    it 'raises if no block given' do
      expect {
        subject.wait_until
      }.to raise_error(ArgumentError)
    end

    context "with a zero timeout" do
      it "yields once returning true" do
        @count = 0
        expect(subject.wait_until(timeout: 0.0) { @count += 1; true }).to eq true
        expect(@count).to eq 1
        expect(@time_elapsed).to eq(0.0)

      end

      it "yields once returning false" do
        @count = 0
        expect(subject.wait_until(timeout: 0.0) { @count += 1; false }).to eq false
        expect(@count).to eq 1
        expect(@time_elapsed).to eq(0.0)
      end
    end
  end

  describe '#wait!' do
    it 'returns value from wait' do
      retval = double()

      value = subject.wait_until! { retval }

      expect(value).to be retval
    end

    it 'raises when wait times out' do
      expect {
        subject.wait_until!("something that is never true") { false }
      }.to raise_error(Timeout::Error, "Timeout after waiting 300.0s until: something that is never true")
    end
  end
end
