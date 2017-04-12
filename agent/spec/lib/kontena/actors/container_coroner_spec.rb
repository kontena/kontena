
describe Kontena::Actors::ContainerCoroner, celluloid: true do
  let(:subject) { described_class.new('id') }

  describe '#start' do
    it 'calls process' do
      expect(subject.wrapped_object).to receive(:process).once
      subject.start
    end

    it 'does not call process if already processing' do
      expect(subject.wrapped_object).to receive(:process).once
      subject.start
      subject.start
    end
  end

  describe '#stop' do
    it 'sets processing to false' do
      expect(subject.wrapped_object).to receive(:process).once
      subject.start
      expect {
        subject.stop
      }.to change { subject.processing? }.from(true).to(false)
    end
  end

  describe '#report' do
    it 'retries if request throws error' do
      retries = 0
      success = false
      allow(subject.wrapped_object).to receive(:rpc_request) {
        if retries == 0
          retries += 1
          raise "error"
        else
          success = true
        end
      }
      expect {
        subject.report([])
      }.to change { success }.from(false).to(true)
    end
  end
end
