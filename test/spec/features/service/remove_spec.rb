describe 'service remove' do

    after(:each) do
      run 'kontena service rm --force rm-test'
      run 'kontena service rm --force rm-test-1'
      run 'kontena service rm --force rm-test-2'
    end

    it 'removes a service' do
      run! 'kontena service create rm-test redis:3-alpine'
      run! 'kontena service rm --force rm-test'
    end

    it 'removes multiple services' do
      run! 'kontena service create rm-test-1 redis:3-alpine'
      run! 'kontena service create rm-test-2 redis:3-alpine'
      run! 'kontena service rm --force rm-test-1 rm-test-2'
    end
  end
