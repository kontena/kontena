describe 'service remove' do

    after(:each) do
      run 'kontena service rm --force $(kontena service ls -q)'
    end

    it 'removes a service' do
      run 'kontena service create rm-test redis:3-alpine'
      k = run 'kontena service rm --force rm-test'
      expect(k.code).to eq(0)
    end

    it 'removes multiple services' do
      run 'kontena service create rm-test-1 redis:3-alpine'
      run 'kontena service create rm-test-2 redis:3-alpine'
      k = run 'kontena service rm --force rm-test-1 rm-test-2'
      expect(k.code).to eq(0)
    end
  end