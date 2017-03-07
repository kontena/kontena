
describe Kontena::Workers::ImageCleanupWorker do
  let(:subject) { described_class.new(false) }
  let(:image_map) {
    [
      {
        "RepoTags" => ["ubuntu:latest", "ubuntu:16.04"],
        "Id" => "8dbd9e392a964056420e5d58ca5cc376ef18e2de93b5cc90e868a1bbc8318c1a"
      },
      {
        "RepoTags" => nil,
        "Id" => "8dbd9e392a964056420e5d58ca5cc376ef18e2de93b5cc90e868a1bbc8318c1b"
      },
      {
        "RepoTags" => [described_class::IGNORE_IMAGES[0]],
        "Id" => "8dbd9e392a964056420e5d58ca5cc376ef18e2de93b5cc90e868a1bbc8318c1c"
      }
    ].map{ |i| Docker::Image.new(Docker.connection, i) }.map{|i| [i.id, i]}.to_h
  }
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#reject_ignored_images' do
    it 'rejects images that are listed in IGNORE_IMAGES' do
      images = image_map
      keep_id = images.keys[2]
      expect {
        subject.reject_ignored_images(images)
      }.to change{ images.size }.by(-1)
      expect(images.keys).not_to include(keep_id)
    end
  end

  describe '#reject_used_images' do
    let(:container) { spy(:container) }
    before(:each) {
      allow(Docker::Container).to receive(:all).and_return([container])
    }

    it 'rejects image that is in use' do
      keep_id = image_map.keys[1]
      allow(container).to receive(:info).and_return({"ImageID" => keep_id})
      images = image_map
      expect {
        subject.reject_used_images(images)
      }.to change{ images.size }.by(-1)
      expect(images.keys).not_to include(keep_id)
    end
  end
end
