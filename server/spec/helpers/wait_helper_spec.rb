
describe WaitHelper do

  let(:klass) {
    Class.new { include WaitHelper }
  }

  let(:subject) {
    klass.new
  }

  describe 'wait' do
    let :time_now do
      Time.now.to_f
    end

    it 'returns true immediately' do
      expect(subject).not_to receive(:sleep)
      value = subject.wait_until { true }
      expect(value).to be_truthy
    end

    it 'sleeps between retries and logs debug' do
      expect(subject).to receive(:_wait_now).and_return(time_now).once
      expect(subject).to receive(:_wait_now).and_return(time_now + 0.5).once
      expect(subject).to receive(:sleep).once
      expect(subject).to receive(:debug).with('wait... foo')
      expect(subject).to_not receive(:sleep)

      @loop = 0
      value = subject.wait_until(timeout: 2, message: 'foo') { (@loop += 1) > 1 }

      expect(value).to be_truthy
    end

    it 'sleeps between retries before timing out' do
      expect(subject).to receive(:_wait_now).and_return(time_now).once
      expect(subject).to receive(:_wait_now).and_return(time_now + 0.5).once
      expect(subject).to receive(:sleep).once
      expect(subject).to receive(:_wait_now).and_return(time_now + 1.0).once
      expect(subject).to receive(:sleep).once
      expect(subject).to receive(:_wait_now).and_return(time_now + 1.5).once
      expect(subject).to receive(:sleep).once
      expect(subject).to receive(:_wait_now).and_return(time_now + 2.001).once
      expect(subject).to_not receive(:sleep)

      value = subject.wait_until(timeout: 2) { false }

      expect(value).to be_falsey
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

      end

      it "yields once returning false" do
        @count = 0
        expect(subject.wait_until(timeout: 0.0) { @count += 1; false }).to eq false
        expect(@count).to eq 1
      end
    end
  end

  describe '#wait!' do
    it 'return value from wait' do
      retval = double()

      expect(subject).to_not receive(:sleep)
      value = subject.wait_until! { retval }

      expect(value).to be retval
    end

    it 'raises when wait return false' do
      expect(subject).to receive(:wait_until).and_return(nil)

      expect {
        subject.wait_until!(message: 'foo') { false }
      }.to raise_error(Timeout::Error)
    end
  end
end
