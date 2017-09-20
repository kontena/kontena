describe Kontena::ServicePods::LifecycleHookManager do

  let(:service_pod) do
    double(:service_pod,
      service_id: 'a',
      instance_number: 2,
      hooks: [
        { 'id' => '1', 'type' => 'pre_start', 'cmd' => 'sleep 1'},
        { 'id' => '2', 'type' => 'post_start', 'cmd' => 'sleep 2'},
        { 'id' => '3', 'type' => 'pre_stop', 'cmd' => 'sleep 3'}
      ]
    )
  end

  let(:subject) { described_class.new(double(:node, id: 'asdasd')) }

  before(:each) do
    subject.track(service_pod)
    allow(subject).to receive(:rpc_client).and_return(spy)
  end

  describe '#hooks_for' do
    it 'returns only hooks for given type' do
      hooks = subject.hooks_for('pre_start')
      expect(hooks.size).to eq(1)
      expect(hooks[0]['cmd']).to eq('sleep 1')
    end

    it 'returns oneshot hooks only once' do
      allow(service_pod).to receive(:service_id).and_return('abc')
      allow(service_pod).to receive(:instance_number).and_return(1)
      allow(service_pod).to receive(:hooks).and_return([
        { 'id' => 'a', 'type' => 'pre_start', 'cmd' => 'sleep 1', 'oneshot' => true }
      ])
      allow(subject).to receive(:rpc_client).and_return(spy)
      expect(subject.hooks_for('pre_start').size).to eq(1)
      expect(subject.hooks_for('pre_start').size).to eq(0)
    end
  end

  describe '#cached_oneshot_hook?' do
    it 'returns false if not oneshot' do
      expect(subject.cached_oneshot_hook?({ 'id' => 'a', 'oneshot' => false })).to be_falsey
    end

    it 'returns false if oneshot but not cached' do
      expect(subject.cached_oneshot_hook?({'id' => 'a', 'oneshot' => true })).to be_falsey
    end

    it 'returns true if oneshot and cached' do
      hook = { 'id' => 'a', 'oneshot' => true }
      subject.oneshot_cache << hook['id']
      expect(subject.cached_oneshot_hook?(hook)).to be_truthy
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