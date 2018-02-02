require 'spec_helper'

describe 'plugin install' do
  after(:each) do
    run('kontena plugin uninstall aws')
  end

  it 'installs a plugin' do
    run!('kontena plugin install aws')
    k = run!('kontena plugin ls')
    expect(k.out).to match(/aws/)
  end

  it 'attempts to upgrade a plugin' do
    run!('kontena plugin install aws')
    k = run!('kontena plugin ls')
    expect(k.out).to match(/aws/)
    k = run!('kontena plugin install aws')
    expect(k.out).to match(/Upgrad/)
  end
end
