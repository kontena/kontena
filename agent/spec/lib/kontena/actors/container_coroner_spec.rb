
describe Kontena::Actors::ContainerCoroner, celluloid: true do
  let(:subject) { described_class.new('id', false) }

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
