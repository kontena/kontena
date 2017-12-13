describe Kontena::Watchdog, :celluloid => true do
  let(:context) { double() }

  subject do
    @watchdog = described_class.watch(interval: 0.01, threshold: 0.05, timeout: 0.1, abort_exit: false) do
      context.ping
    end
  end

  after do
    @watchdog.terminate if @watchdog.alive?
  end

  it "does nothing if the watchdog block is okay" do
    allow(context).to receive(:ping) do
      nil
    end

    expect(subject.wrapped_object).to_not receive(:abort)

    subject
    sleep 0.2
  end

  it "aborts the thread if the watchdog block raises" do
    allow(context).to receive(:ping) do
      raise RuntimeError, 'testing'
    end

    expect(subject.wrapped_object).to receive(:abort).with(RuntimeError).and_call_original

    subject
    sleep 0.2
  end

  it "aborts the thread if the watchdog block timeouts" do
    allow(context).to receive(:ping) do
      sleep 1
    end

    expect(subject.wrapped_object).to receive(:bark).at_least(:once).and_call_original
    expect(subject.wrapped_object).to receive(:bite).once.and_call_original
    expect(subject.wrapped_object).to receive(:abort).with(Timeout::Error).and_call_original

    subject
    sleep 0.2
  end
end
