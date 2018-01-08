require 'spec_helper'

describe 'vpn create' do
  before(:each) do
    # Due to async nature of stack/service removals, need to wait until possible previous vpn containers have gone
    wait_until_container_gone('vpn.server-1')
  end

  after(:each) do
    run! 'kontena stack rm --force vpn'
  end

  it 'creates a vpn stack' do
    k = run! 'kontena vpn create'
    k = run! 'kontena stack show vpn'
    expect(k.out.match(/state: running/))
  end
end
