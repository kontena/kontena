require 'spec_helper'

describe 'vpn config' do
  before(:each) do
    # Due to async nature of stack/service removals, need to wait until possible previous vpn containers have gone
    wait_until_container_gone('vpn.server-1')
  end

  after(:each) do
    run 'kontena stack rm --force vpn'
  end

  it 'outputs a working openvpn config' do
    k = run 'kontena vpn create'
    expect(k.code).to eq(0)
    k = run 'kontena vpn config'
    expect(k.code).to eq(0)
    expect(k.out.match(/BEGIN PRIVATE KEY/))
  end
end
