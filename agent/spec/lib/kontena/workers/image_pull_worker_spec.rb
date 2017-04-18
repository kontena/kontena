
describe Kontena::Workers::ImagePullWorker, celluloid: true do

  let(:subject) { described_class.new }

  describe '#pull_image' do
    it 'pulls docker image' do
      expect(Docker::Image).to receive(:create).once.and_return(true)
      subject.pull_image('redis:latest', 'rev', nil)
    end

    it 'aborts if docker image is not found' do
      allow(subject.wrapped_object).to receive(:sleep).with(0.1).at_least(1).times
      expect(Docker::Image).to receive(:create).exactly(10).times do
        raise Docker::Error::NotFoundError.new('not found')
      end
      expect {
        subject.pull_image('redis:latest', 'rev', nil)
      }.to raise_error(Docker::Error::NotFoundError)
      expect(subject.alive?).to be_truthy
    end
  end

  describe '#fresh_pull?' do
    it 'returns false if image has not been pulled' do
      expect(subject.fresh_pull?('redis:latest')).to be_falsey
    end

    it 'returns true if image is just pulled' do
      subject.update_image_cache('redis:latest')
      expect(subject.fresh_pull?('redis:latest')).to be_truthy
    end

    it 'returns false if cache is expired' do
      subject.image_cache['redis:latest'] = Time.now - 60*60*8
      expect(subject.fresh_pull?('redis:latest')).to be_falsey
    end
  end

  describe '#ensure_image' do
    it 'serializes image pulls' do
      pulls = []
      allow(subject.wrapped_object).to receive(:pull_image) do |image, rev|
        sleep 0.005
        pulls << rev.to_i
      end
      10.times do |i|
        subject.async.ensure_image('redis:latest', i)
      end
      sleep 0.01 until pulls.size == 10
      expect(pulls).to eq([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    end
  end
end
