require 'spec_helper'

describe 'plugin uninstall' do
  before(:each) do
    run('kontena plugin install aws')
  end

  it 'removes installed plugin' do
    k = run('kontena plugin uninstall aws')
    expect(k.code).to eq(0)
  end
end
