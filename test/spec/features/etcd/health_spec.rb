require 'spec_helper'

describe 'etcd health' do
  it 'outputs node etcd health status' do
    k = run! 'kontena etcd health'
    expect(k.out.match(/node(.*)is healthy/i))
  end
end
