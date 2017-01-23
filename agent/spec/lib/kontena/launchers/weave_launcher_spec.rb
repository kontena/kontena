describe Kontena::Launchers::Weave do
  let :node_info do
    instance_double(Kontena::Models::NodeInfo)
  end
  let :node_info_observable do
    Kontena::Actors::Observable.new
  end

  let :actor do
    described_class.new(node_info_observable, start: false)
  end
  subject do
    actor.wrapped_object
  end

  it "observes the NodeInfo", :celluloid => true do
    node_info_observable.update(node_info)

    expect(subject).to receive(:up).with(node_info)

    actor.start
  end

  describe '#up' do
    
  end
end
