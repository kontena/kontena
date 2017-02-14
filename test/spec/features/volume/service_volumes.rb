require 'spec_helper'
require 'json'

describe 'service volumes' do
  after(:each) do
    run "kontena service rm --force null/redis"
    run "kontena volume rm null/testVol"
  end

  it 'service uses a volume' do
    k = run "kontena volume create null testVol"
    expect(k.code).to eq(0)
    k = run "kontena service create -v testVol:/data redis redis:alpine"
    expect(k.code).to eq(0)
    k = run "kontena service deploy redis"
    expect(k.code).to eq(0)
    k = run "kontena container inspect moby/redis-1"

    json = JSON.parse(k.out)
    mount = json.dig('Mounts').find { |m| m['Name'] =~ /testVol/}
    expect(mount).not_to be_nil
    expect(mount['Name']).to eq("testVol-redis-1")
    expect(mount['Destination']).to eq('/data')
  end

  it 'volume cannot be removed when still used by a service' do
    k = run "kontena volume create null testVol"
    expect(k.code).to eq(0)
    k = run "kontena service create -v testVol:/data redis redis:alpine"
    expect(k.code).to eq(0)
    k = run "kontena volume rm null/testVol"
    expect(k.code).not_to eq(0)
  end

end
