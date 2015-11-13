require_relative '../../../spec_helper'

describe Kontena::Rpc::DockerImageApi do

  let(:image) { double(:image, as_json: {})}

  describe '#create' do
    it 'calls Docker::Image.create' do
      expect(subject).to receive(:create).and_return(image)
      subject.create({})
    end
  end

  describe '#show' do
    it 'gets image from docker' do
      expect(subject).to receive(:show).and_return(image)
      subject.show({})
    end
  end
end
