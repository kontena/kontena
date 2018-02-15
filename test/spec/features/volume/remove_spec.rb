describe 'volume remove' do
  after(:each) do
    run 'kontena volume rm --force test-volume'
    run 'kontena volume rm --force test-volume0'
    run 'kontena volume rm --force test-volume1'
  end

  it 'removes a volume' do
    run! 'kontena volume create --driver local --scope grid test-volume'
    run! 'kontena volume rm --force test-volume'
  end

  it 'removes multiple volumes' do
    2.times do |i|
      run! "kontena volume create --driver local --scope grid test-volume#{i}"
    end
    run! 'kontena volume rm --force test-volume0 test-volume1'
  end
end
