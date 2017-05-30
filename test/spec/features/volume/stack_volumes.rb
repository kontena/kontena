require 'spec_helper'
require 'json'
require_relative 'common'

describe 'stack volumes' do
  include Common

  after(:each) do
    run "kontena stack rm --force redis"
    run "kontena volume rm --force redis-data"
  end


  it 'creates stack with reference to external volume' do
    k = run 'kontena volume create --scope instance --driver local redis-data'
    expect(k.code).to eq(0)
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install redis-simple.yml'
      expect(k.code).to eq(0), k.out
    end

    container = find_container('redis.redis-1')
    mount = container_mounts(container).find { |m| m['Name'] =~ /redis-data-1/}
    expect(mount).not_to be_nil
    expect(mount['Name']).to eq("redis.redis.redis-data-1")
    expect(mount['Destination']).to eq('/data')
  end

  it 'fails to create stack with reference to non-existing external volume' do
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install redis-simple.yml'
      expect(k.code).not_to eq(0)
    end
  end

  it 'fails to install stack with stack scoped volume' do
    with_fixture_dir("stack/volumes") do
      k = run 'kontena stack install redis-with-volume.yml'
      expect(k.code).not_to eq(0)
    end
    k = run 'kontena stack show redis'
    expect(k.code).not_to eq(0)
  end

end
