describe Kontena::ServicePods::LifecycleHookManager do

  let(:service_pod) do
    double(:service_pod, hooks: [
      { 'type' => 'pre_start', 'cmd' => 'sleep 1'},
      { 'type' => 'post_start', 'cmd' => 'sleep 2'},
      { 'type' => 'pre_stop', 'cmd' => 'sleep 3'}
    ])
  end

  let(:subject) { described_class.new(double(:node, id: 'asdasd')) }

  before(:each) do
    subject.track(service_pod)
  end

  describe '#hooks_for' do
    it 'returns only hooks for given type' do
      hooks = subject.hooks_for('pre_start')
      expect(hooks.size).to eq(1)
      expect(hooks[0]['cmd']).to eq('sleep 1')
    end
  end

  describe '#build_cmd' do
    it 'returns array' do
      cmd = subject.build_cmd("echo 'hello'")
      expect(cmd[0]).to eq('/bin/sh')
      expect(cmd[2]).to eq("echo 'hello'")
    end
  end

  describe '#on_pre_start' do
    it 'runs pre_start hooks' do
      expect(subject).to receive(:hooks_for).with('pre_start').and_return([])
      subject.on_pre_start
    end
  end

  describe '#on_post_start' do
    it 'runs post_start hooks' do
      expect(subject).to receive(:hooks_for).with('post_start').and_return([])
      subject.on_post_start(double(:service_container))
    end
  end

  describe '#on_pre_stop' do
    it 'runs pre_stop hooks' do
      expect(subject).to receive(:hooks_for).with('pre_stop').and_return([])
      subject.on_pre_stop(double(:service_container))
    end
  end
end