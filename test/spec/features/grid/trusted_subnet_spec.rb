describe 'grid trusted-subnet' do
  describe 'list' do
    it 'lists subnets' do
      k = run "kontena grid trusted-subnet ls"
      expect(k.code).to eq(0)
    end
  end

  describe 'add' do
    after(:each) do
      run "kontena grid trusted-subnet rm --force 192.168.22.0/24"
    end

    it 'adds a subnet' do
      k = run "kontena grid trusted-subnet add 192.168.22.0/24"
      expect(k.code).to eq(0)
    end
  end

  describe 'remove' do
    it 'removes subnet' do
      run "kontena grid trusted-subnet add 192.168.23.0/24"
      k = run "kontena grid trusted-subnet rm --force 192.168.23.0/24"
      expect(k.code).to eq(0)
    end
  end
end