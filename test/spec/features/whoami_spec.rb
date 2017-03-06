require 'spec_helper'

describe 'whoami' do
  it 'outputs info about grid & user' do
    k = run 'kontena whoami'
    expect(k.code).to eq(0)
    expect(k.out.match(/^grid: e2e/i))
    expect(k.out.match(/^user: admin/i))
  end
end
