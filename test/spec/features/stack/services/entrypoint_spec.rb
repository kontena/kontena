describe 'stack service entrypoint' do
  include ContainerHelper

  context 'for a stack service with an entrypoint' do
    before(:all) do
      with_fixture_dir("stack/entrypoint") do
        run! 'kontena stack install sleep.yml'
      end
    end

    after(:all) do
      run! 'kontena stack rm --force sleep'
    end

    it 'configures the container with the nested /w/w entrypoint' do
      inspect = inspect_container(container_id('sleep.sleep-1'))

      expect(inspect['Config']['Entrypoint']).to eq ['/w/w']
      expect(inspect['Config']['Cmd']).to eq ['/bin/sleep', '300']
    end
  end

  context 'for a stack service with an entrypoint in network_mode=host' do
    before(:all) do
      with_fixture_dir("stack/entrypoint") do
        run! 'kontena stack install etcdctl-watch.yml'
      end
    end

    after(:all) do
      run! 'kontena stack rm --force etcdctl-watch'
    end

    it 'configures the container with the correct entrypoint' do
      inspect = inspect_container(container_id('etcdctl-watch.etcdctl-1'))

      expect(inspect['Config']['Entrypoint']).to eq ['/usr/bin/etcdctl']
      expect(inspect['Config']['Cmd']).to eq ['watch', '--forever', '--recursive', '/']
    end
  end
end
