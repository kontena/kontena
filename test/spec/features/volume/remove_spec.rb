describe 'volume remove' do
  after(:each) do
    run 'kontena volume rm --force $(kontena volume ls -q)'
  end

  it 'removes a volume' do
    run 'kontena volume create --driver local --scope grid test-volume'
    k = run 'kontena volume rm --force test-volume'
    expect(k.code).to eq(0)
  end

  it 'removes multiple volumes' do
    2.times do |i|
      run "kontena volume create --driver local --scope grid test-volume#{i}"
    end
    k = run 'kontena volume rm --force test-volume0 test-volume1'
    expect(k.code).to eq(0)
  end
end