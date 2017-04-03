require 'spec_helper'
require 'json'
require_relative 'common'

describe 'stack volumes' do
  include Common

  after(:each) do
    run "kontena stack rm --force redis"
    run "kontena volume rm redis-data"
  end

  it 'stack creates volumes' do
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install redis-simple.yml'
      expect(k.code).to eq(0), k.out
    end
    k = run 'kontena volume ls'
    expect(k.out.match(/redis-data/)).to be_truthy
    container = find_container('redis.redis-1')
    puts "****** #{container}"
    mount = container_mounts(container).find { |m| m['Name'] =~ /redis-data-1/}
    expect(mount).not_to be_nil
    expect(mount['Name']).to eq("redis.redis.redis-data-1")
    expect(mount['Destination']).to eq('/data')
  end

  it 'fails to install stack with missing volume driver' do
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install missing-driver.yml'
      expect(k.code).not_to eq(0)
    end
    k = run 'kontena stack show redis'
    expect(k.code).not_to eq(0)
  end

  it 'fails to update stack with missing volume driver' do
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install redis-simple.yml'
      expect(k.code).to eq(0), k.out
    end
    k = run 'kontena stack upgrade redis missing-driver.yml'
    expect(k.code).not_to eq(0)
  end



end
