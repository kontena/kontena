require 'spec_helper'

describe 'vpn create' do
  it 'creates a vpn stack' do
    k = run 'kontena vpn create'
    expect(k.code).to eq(0)
    k = run 'kontena stack show vpn'
    expect(k.out.match(/state: running/))
    run 'kontena stack rm --force vpn'
  end
end
