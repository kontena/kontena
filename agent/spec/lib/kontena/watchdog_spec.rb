describe Kontena::Watchdog, :celluloid => true do
  subject do
    @watchdog = described_class.new(block, interval: 0.01, timeout: 0.1, abort_exit: false)
  end

  after do
    @watchdog.terminate if @watchdog.alive?
  end

  context "with a block that is okay" do
    let(:block) { Proc.new do
      true
    end}

    it "does nothing" do
      expect(subject.wrapped_object).to_not receive(:abort)

      subject
      sleep 0.2
    end
  end

  context "with a block that raises" do
    let(:block) { Proc.new do
      raise RuntimeError, 'testing'
    end}

    it "abort" do
      expect(subject.wrapped_object).to receive(:abort).with(RuntimeError).and_call_original

      subject
      sleep 0.2
    end
  end

  context "with a block that times out" do
    let(:block) { Proc.new do
      sleep 1
    end}

    it "aborts" do
      expect(subject.wrapped_object).to receive(:abort).with(Timeout::Error).and_call_original

      subject
      sleep 0.2
    end
  end
end
