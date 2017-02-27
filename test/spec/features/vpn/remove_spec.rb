require 'spec_helper'

describe 'vpn remove' do
  it 'removes the vpn stack' do
    run 'kontena vpn create'
    k = run 'kontena stack rm --force vpn'
    expect(k.code).to eq(0)
    k = run 'kontena stack show vpn'
    expect(k.code).not_to eq(0)
  end
end
