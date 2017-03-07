
describe Kontena::Helpers::WaitHelper do

  let(:klass) {
    Class.new { include Kontena::Helpers::WaitHelper }
  }

  let(:subject) {
    klass.new
  }

  describe 'wait' do
    let :time_now do
      Time.now
    end

    it 'returns true immediately' do
      expect(subject).not_to receive(:sleep)
      value = subject.wait { true }
      expect(value).to be_truthy
    end

    it 'sleeps between retries and logs debug' do
      expect(Time).to receive(:now).and_return(time_now).once
      expect(Time).to receive(:now).and_return(time_now + 0.5).once
      expect(subject).to receive(:sleep).once
      expect(subject).to receive(:debug).with('foo')
      expect(subject).to_not receive(:sleep)

      @loop = 0
      value = subject.wait(timeout: 2, message: 'foo') { (@loop += 1) > 1 }

      expect(value).to be_truthy
    end

    it 'sleeps between retries before timing out' do
      expect(Time).to receive(:now).and_return(time_now).once
      expect(Time).to receive(:now).and_return(time_now + 0.5).once
      expect(subject).to receive(:sleep).once
      expect(Time).to receive(:now).and_return(time_now + 1.0).once
      expect(subject).to receive(:sleep).once
      expect(Time).to receive(:now).and_return(time_now + 1.5).once
      expect(subject).to receive(:sleep).once
      expect(Time).to receive(:now).and_return(time_now + 2.001).once
      expect(subject).to_not receive(:sleep)

      value = subject.wait(timeout: 2) { false }

      expect(value).to be_falsey
    end

    it 'raises if no block given' do
      expect {
        subject.wait
      }.to raise_error(ArgumentError)
    end
  end

  describe '#wait!' do
    it 'return true when wait gives true' do
      expect(subject).to receive(:wait).and_return(true)
      value = subject.wait! { true }
      expect(value).to be_truthy
    end

    it 'raises when wait return false' do
      expect(subject).to receive(:wait).and_return(false)
      expect {
        subject.wait!(message: 'foo') { false }
      }.to raise_error(Timeout::Error, "Timeout while: foo")
    end
  end
end
