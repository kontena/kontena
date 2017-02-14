require 'spec_helper'

describe 'volume create' do
  after(:each) do
    run "kontena volume rm null/testVol"
  end

  it 'creates a volume' do
    k = run "kontena volume create null testVol"
    expect(k.code).to eq(0)
    k = run "kontena volume ls"
    expect(k.out.match(/null\/testVol/)).to be_truthy
  end


  it 'removes a volume' do
    k = run "kontena volume create null testVol"
    expect(k.code).to eq(0)

    k = run "kontena volume rm null/testVol"
    expect(k.code).to eq(0)

    k = run "kontena volume ls"
    expect(k.out.match(/null\/testVol/)).to be_falsey
  end
end
