require 'spec_helper'

describe 'plugin install' do
  after(:each) do
    run('kontena plugin uninstall --force aws')
  end

  it 'installs a plugin' do
    k = run('kontena plugin install aws')
    expect(k.code).to eq(0)
    k = run('kontena plugin ls')
    expect(k.out).to match(/aws/)
  end

  it 'attempts to upgrade a plugin' do
    k = run('kontena plugin install aws')
    expect(k.code).to eq(0)
    k = run('kontena plugin ls')
    expect(k.out).to match(/aws/)
    k = run('kontena plugin install aws')
    expect(k.code).to eq(0)
    expect(k.out).to match(/Upgrad/)
  end
end
