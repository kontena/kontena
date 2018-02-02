describe 'service create' do

  after(:each) do
    run 'kontena service rm --force create-test'
  end

  it 'creates a service' do
    run! 'kontena service create create-test redis:3-alpine'
    # TODO result check
  end
end
