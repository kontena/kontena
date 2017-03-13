
describe Kontena::NetworkAdapters::WeaveExecutor do

  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
  end

  describe '#censor_password' do
    it 'removes password' do
      expect(subject.send(:censor_password, ['foo', '--password', 'passwd', 'bar'])).to eq(['foo', '--password', '<redacted>', 'bar'])
    end

    it 'does not alter if no --password exist' do
      expect(subject.send(:censor_password, ['foo', 'passwd', 'bar'])).to eq(['foo', 'passwd', 'bar'])
    end

  end

end
