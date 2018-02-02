describe 'node remove' do

  after(:each) do
    run 'kontena node rm --force rm-test-1 rm-test-2'
  end

  it 'removes a node' do
    run! 'kontena node create rm-test-1'
    run! 'kontena node rm --force rm-test-1'
    # TODO result check
  end

  it 'removes multiple nodes' do
    run! 'kontena node create rm-test-1'
    run! 'kontena node create rm-test-2'
    run! 'kontena node rm --force rm-test-1 rm-test-2'
    # TODO result check
  end
end
