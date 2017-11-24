require 'spec_helper'

describe 'plugin search' do
  it 'lists available plugins' do
    k = run('kontena plugin search')
    expect(k.code).to eq(0)
    expect(k.out).to match(/aws/)
    expect(k.out).to match(/azure/)
    expect(k.out).to match(/packet/)
  end
end
