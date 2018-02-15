describe 'vpn' do
  context 'with a created vpn stack' do
    before(:all) do
      # Due to async nature of stack/service removals, need to wait until possible previous vpn containers have gone
      wait_until_container_gone('vpn.server-1')

      run! 'kontena vpn create'
    end

    after(:all) do
      run 'kontena stack rm --force vpn'
    end

    it 'creates a vpn stack' do
      k = run! 'kontena stack show vpn'

      expect(k.out.match(/state: running/))
    end

    describe 'config' do
      it 'outputs a working openvpn config' do
        k = run! 'kontena vpn config'

        expect(k.out.match(/BEGIN PRIVATE KEY/))
      end
    end
  end
end
