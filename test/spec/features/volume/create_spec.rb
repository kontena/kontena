require 'spec_helper'

describe 'volume create' do
  after(:each) do
    run "kontena volume rm --force testVol"
  end

  it 'creates a volume' do
    k = run "kontena volume create --driver local --scope instance testVol"
    expect(k.code).to eq(0)
    k = run "kontena volume ls"
    expect(k.out.match(/testVol/)).to be_truthy
  end

  it 'fails to create volume without driver' do
    k = run "kontena volume create --scope instance testVol"
    expect(k.code).not_to eq(0)
  end


  it 'fails to create volume without scope' do
    k = run "kontena volume create --driver local testVol"
    expect(k.code).not_to eq(0)
  end


  it 'removes a volume' do
    k = run "kontena volume create --driver local --scope instance testVol"
    expect(k.code).to eq(0)

    k = run "kontena volume rm --force testVol"
    expect(k.code).to eq(0)

    k = run "kontena volume ls"
    expect(k.out.match(/testVol/)).to be_falsey
  end
end
