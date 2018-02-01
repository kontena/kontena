describe 'vault remove' do
  after(:each) do
    run 'kontena vault rm --force foo'
    run 'kontena vault rm --force foo0'
    run 'kontena vault rm --force foo1'
  end

  it 'removes a vault key' do
    run! 'kontena vault write foo bar'
    run! 'kontena vault rm --force foo'
  end

  it 'removes multiple vault keys' do
    2.times do |i|
      run! "kontena vault write foo#{i} bar"
    end
    run! 'kontena vault rm --force foo0 foo1'
  end
end
