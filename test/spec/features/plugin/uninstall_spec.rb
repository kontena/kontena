require 'spec_helper'

describe 'plugin uninstall' do
  before(:each) do
    run('kontena plugin install aws')
  end

  it 'removes installed plugin' do
    k = run('kontena plugin uninstall aws')
    expect(k.code).to eq(0)

    k = run('kontena plugin ls')
    expect(k.code).to eq(0)
    expect(k.out).to_not match(/aws/)
  end
end
