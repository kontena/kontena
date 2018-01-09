describe 'vault remove' do
  after(:each) do
    run 'kontena vault rm --force $(kontena vault ls -q)'
  end

  it 'removes a vault key' do
    run 'kontena vault write foo bar'
    k = run 'kontena vault rm --force foo'
    expect(k.code).to eq(0)
  end

  it 'removes multiple vault keys' do
    2.times do |i|
      run "kontena vault write foo#{i} bar"
    end
    k = run 'kontena vault rm --force foo0 foo1'
    expect(k.code).to eq(0)
  end
end