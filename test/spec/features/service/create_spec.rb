describe 'service create' do

  after(:each) do
    run 'kontena service rm --force create-test'
  end

  it 'creates a service' do
    k = run 'kontena service create create-test redis:3-alpine'
    expect(k.code).to eq(0)
  end
end