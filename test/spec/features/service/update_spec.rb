describe 'service update' do
  before(:each) do
    run("kontena service create test-1 nginx:1-alpine")
  end

  after(:each) do
    run("kontena service rm --force test-1")
  end

  context 'health check' do
    it 'updates health check' do
      run! "kontena service update --health-check-port 8080 --health-check-protocol http --health-check-uri / test-1"
      k = run! "kontena service show test-1"
      expect(k.out.match(/port: 8080/)).to be_truthy
      expect(k.out.match(/protocol: http/)).to be_truthy
      expect(k.out.match(/uri: \//)).to be_truthy
    end

    it 'allows to remove health check' do
      run "kontena service update --health-check-port 8080 --health-check-protocol http --health-check-uri / test-1"
      k = run! "kontena service update --health-check-port none --health-check-protocol none test-1"
      expect(k.out.match(/port: 8080/)).not_to be_truthy
    end
  end

  context 'stop_grace_period' do
    it 'allows update stop-timeout' do
      run! "kontena service update --stop-timeout 1m23s test-1"
      k = run! "kontena service show test-1"
      expect(k.out.match(/stop_grace_period: 83s/)).to be_truthy
    end
  end
end
