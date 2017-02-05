require 'spec_helper'

describe 'plugin list' do
  it "returns list" do
    k = run('kontena plugin ls')
    expect(k.code).to eq(0)
  end
end
