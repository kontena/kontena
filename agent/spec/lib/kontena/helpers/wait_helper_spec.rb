require_relative '../../../spec_helper'

describe Kontena::Helpers::WaitHelper do

  let(:klass) {
    Class.new { include Kontena::Helpers::WaitHelper }
  }

  let(:subject) {
    klass.new
  }

  describe 'wait' do
    it 'returns true immediately' do
      expect(Kernel).not_to receive(:sleep)
      value = subject.wait { true }
      expect(value).to be_truthy
    end

    it 'sleeps between retries' do
      expect(subject).to receive(:still_waiting?).and_return(true, true, false)
      expect(subject).to receive(:sleep).twice
      value = subject.wait(2) { false }
      expect(value).to be_falsey
    end

    it 'debugs given message' do
      expect(subject).to receive(:still_waiting?).and_return(true, false)
      expect(subject).to receive(:debug).with('foo')
      expect(subject).to receive(:sleep).once
      value = subject.wait(2, 'foo') { false }
      expect(value).to be_falsey
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
        subject.wait! { false }
      }.to raise_error
    end
  end

  describe 'still_waiting?' do
    it 'return true if more waiting needed' do
      wait_until = Time.now.to_f - 1.0
      expect(subject.still_waiting?(wait_until)).to be_truthy
    end

    it 'return true if more waiting needed' do
      wait_until = Time.now.to_f + 1.0
      expect(subject.still_waiting?(wait_until)).to be_falsey
    end
  end

end
