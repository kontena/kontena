describe 'node remove' do

  after(:each) do
    run 'kontena node rm --force rm-test-1 rm-test-2'
  end

  it 'removes a node' do
    run 'kontena node create rm-test-1'
    k = run 'kontena node rm --force rm-test-1'
    expect(k.code).to eq(0)
  end

  it 'removes multiple nodes' do
    run 'kontena node create rm-test-1'
    run 'kontena node create rm-test-2'
    k = run 'kontena node rm --force rm-test-1 rm-test-2'
    expect(k.code).to eq(0)
  end
end