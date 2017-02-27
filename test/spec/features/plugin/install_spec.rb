require 'spec_helper'

describe 'plugin install' do
  after(:each) do
    run('kontena plugin rm --force aws')
  end

  it 'installs a plugin' do
    k = run('kontena plugin install aws')
    expect(k.code).to eq(0)
    k = run('kontena plugin ls')
    expect(k.out).to match(/aws/)
  end
end
