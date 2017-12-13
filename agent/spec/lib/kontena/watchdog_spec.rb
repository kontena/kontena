describe Kontena::Watchdog, :celluloid => true do
  let(:context) { double() }

  subject do
    @watchdog = described_class.watch(interval: 0.01, threshold: 0.05, timeout: 0.1) do
      context.ping
    end
  end

  after do
    @watchdog.terminate if @watchdog.alive?
  end

  it "does nothing if the watchdog block is okay" do
    allow(context).to receive(:ping).and_return(nil)

    expect{
      subject
      sleep 0.5
    }.to_not raise_error
  end

  it "aborts the thread if the watchdog blocks raises" do
    allow(context).to receive(:ping).and_raise(RuntimeError.new 'testing')
    expect{
      subject
      sleep 0.5
    }.to raise_error(Kontena::Watchdog::Abort, 'RuntimeError: testing')
  end

  it "aborts the thread if the watchdog blocks blocks" do
    allow(context).to receive(:ping) do
      sleep 1
    end

    expect(subject.wrapped_object).to receive(:bark).at_least(:once).and_call_original
    expect(subject.wrapped_object).to receive(:bite).once.and_call_original

    expect{
      subject
      sleep 0.5
    }.to raise_error(Kontena::Watchdog::Abort, /Timeout::Error: watchdog timeout after 0.\d+s/)
  end
end
