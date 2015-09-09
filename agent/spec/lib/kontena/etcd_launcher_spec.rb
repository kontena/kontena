require_relative '../../spec_helper'

describe Kontena::EtcdLauncher do

  describe '#start!' do
    it 'returns a thread' do
      allow(subject).to receive(:start_etcd)
      thread = subject.start!
      expect(thread.class).to eq(Thread)
    end

    it 'calls start_etcd' do
      expect(subject).to receive(:start_etcd)
      subject.start!
      sleep 0.1
    end
  end

  describe '#start_etcd' do
    it 'creates an etcd container with data-volumes' do
      expect(subject).to receive(:create_data_container)
      expect(subject).to receive(:weave_running?).and_return(true)
      expect(subject).to receive(:create_container)
      expect(subject).to receive(:pull_image).once
      subject.start_etcd
    end
  end
end
