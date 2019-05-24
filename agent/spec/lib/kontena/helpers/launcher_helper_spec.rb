describe Kontena::Helpers::LauncherHelper do
  let(:klass) {
    Class.new do
      include Kontena::Helpers::LauncherHelper
    end
  }
  let(:subject) { klass.new }

  let(:docker_image) { instance_double(Docker::Image,
    id: 'sha256:0d1961b04a4268fd6790fb70af2cba9c4dc04b24630ff85d6297e4afdc440256',
  ) }
  let(:docker_container) { double(Docker::Container,
    id: 'eec27b701a3a334308ec39e1262efe12ace66c26b02d1076c7e5ccc71c30f63a',
  )}

  describe '#inspect_image' do
    it 'returns image if it exists' do
      expect(Docker::Image).to receive(:get).with('test/foo').and_return(docker_image)

      expect(subject.inspect_image('test/foo')).to eq docker_image
    end

    it 'returns nil if the image does not exist' do
      expect(Docker::Image).to receive(:get).with('test/foo').and_raise(Docker::Error::NotFoundError)

      expect(subject.inspect_image('test/foo')).to be nil
    end

    it 'lets other errors propagate' do
      expect(Docker::Image).to receive(:get).with('test/foo').and_raise(Docker::Error::ServerError)

      expect{subject.inspect_image('test/foo')}.to raise_error(Docker::Error::ServerError)
    end
  end

  describe '#ensure_image' do
    it 'does nothing if image already exists' do
      expect(Docker::Image).to receive(:get).with('test/foo').and_return(docker_image)

      expect(subject.ensure_image('test/foo')).to eq docker_image
    end

    it 'pulls image if it does not exist' do
      expect(Docker::Image).to receive(:get).with('test/foo').and_raise(Docker::Error::NotFoundError)
      expect(subject).to receive(:info).with("Pulling image test/foo...")
      expect(Docker::Image).to receive(:create).with({'fromImage' => 'test/foo'}).and_return(docker_image)

      expect(subject.ensure_image('test/foo')).to eq docker_image
    end
  end

  describe '#inspect_container' do
    it 'returns nil if container does not exist' do
      expect(Docker::Container).to receive(:get).with('test-foo').and_raise(Docker::Error::NotFoundError)

      expect(subject.inspect_container('test-foo')).to be nil
    end

    it 'returns container if found' do
      expect(Docker::Container).to receive(:get).with('test-foo').and_return(docker_container)
      expect(subject.inspect_container('test-foo')).to eq docker_container
    end

    it 'lets other errors propagate' do
      expect(Docker::Container).to receive(:get).with('test-foo').and_raise(Docker::Error::ServerError)
      expect{subject.inspect_container('test-foo')}.to raise_error(Docker::Error::ServerError)
    end
  end
end
