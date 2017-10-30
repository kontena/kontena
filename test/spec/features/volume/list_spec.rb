require 'spec_helper'

describe 'volume list' do
  before(:each) do
    run "kontena volume rm --force testVol"
    run "kontena volume rm --force testVol2"
    run "kontena volume create --driver local --scope instance testVol"
    run "kontena volume create --driver local --scope instance testVol2"
  end

  after(:each) do
    run "kontena volume rm --force testVol"
    run "kontena volume rm --force testVol2"
  end

  it 'lists volumes' do
    k = run "kontena volume list"
    expect(k.code).to eq(0)
    expect(k.out.match(/testVol\s+instance\s+local\s+\d/)).to be_truthy
    expect(k.out.match(/testVol2\s+instance\s+local\s+\d/)).to be_truthy
  end

  context '--quiet' do
    it 'lists volume names' do
      k = run "kontena volume ls -q"
      expect(k.code).to eq(0)
      expect(k.out.lines.sort.map(&:chomp)).to eq ["testVol", "testVol2"]
    end
  end
end
