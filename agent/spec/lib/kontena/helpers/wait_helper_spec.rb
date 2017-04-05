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
    it 'returns true immediately without any logging' do
      expect(subject).not_to receive(:sleep)
      expect(subject).not_to receive(:debug)

      value = subject.wait_until { true }

      expect(value).to be_truthy
    end

    it 'sleeps between retries and logs debug while under threshold' do
      expect(subject).to receive(:debug).with('waiting 1.4s of 3.0s until: something that takes two seconds')
      expect(subject).to receive(:debug).with('waited 2.0s of 3.0s until: something that takes two seconds yielded true')

      value = subject.wait_until("something that takes two seconds", timeout: 3, interval: 0.1, threshold: 2.5) { @time_elapsed > 2.0 }

      expect(value).to be_truthy
      expect(@time_elapsed).to be > 2.0
    end

    it 'logs info if over threshold' do
      expect(subject).to receive(:debug).with('waiting 1.5s of 3.0s until: something that takes two seconds')
      expect(subject).to receive(:debug).with('waiting 2.0s of 3.0s until: something that takes two seconds')
      expect(subject).to receive(:info).with('waited 2.5s of 3.0s until: something that takes two seconds yielded true')

      value = subject.wait_until("something that takes two seconds", timeout: 3, interval: 0.5, threshold: 1.0) { @time_elapsed > 2.0 }

      expect(value).to be_truthy
      expect(@time_elapsed).to be > 2.0
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
