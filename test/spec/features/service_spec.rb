require 'spec_helper'

describe 'service commands' do
  context 'list' do
    it 'shows empty list by default' do
      k = run("kontena service ls")
      expect(k.out.split("\r\n").size).to eq(1)
    end

    it 'lists created services' do
      run("kontena service create test-1 redis:3.0")
      run("kontena service create test-2 redis:3.0")
      k = run("kontena service ls")
      output = k.out.split("\r\n")
      expect(output[1]).to match(/test-2/)
      expect(output[2]).to match(/test-1/)

      run("kontena service rm --force test-1")
      run("kontena service rm --force test-2")
    end
  end

  context 'deploy' do
    it 'deploys a service' do
      deployed = false
      run("kontena service create test-1 redis:3.0")
      k = kommando("kontena service deploy test-1")
      expect(k.run).to be_truthy

      run("kontena service rm --force test-1")
    end
  end

  context 'scale' do
    it 'scales service' do
      run("kontena service create test-1 redis:3.0")
      k = kommando("kontena service deploy test-1")
      expect(k.run).to be_truthy
      k = kommando("kontena service scale test-1 3")
      expect(k.run).to be_truthy

      run("kontena service rm --force test-1")
    end
  end

  context 'stop' do
    before(:each) do
      run("kontena service create test-1 redis:3.0")
      run("kontena service create test-2 redis:3.0")
      run("kontena service deploy test-1")
    end

    after(:each) do
      run("kontena service rm --force test-1")
      run("kontena service rm --force test-2")
    end

    it 'stops running service' do
      k = kommando("kontena service stop test-1")
      expect(k.run).to be_truthy
      sleep 1
      k = run("kontena service show test-1")
      expect(k.out.scan('status: stopped').size).to eq(2)
    end

    it 'stops initialized service' do
      k = kommando("kontena service stop test-2")
      expect(k.run).to be_truthy
      sleep 1
      k = run("kontena service show test-2")
      expect(k.out.scan('status: stopped').size).to eq(1)
    end
  end

  context 'start' do
    before(:each) do
      run("kontena service create test-1 redis:3.0")
      run("kontena service create test-2 redis:3.0")
      run("kontena service deploy test-1")
      run("kontena service stop test-1")
    end

    after(:each) do
      run("kontena service rm --force test-1")
      run("kontena service rm --force test-2")
    end

    it 'starts stopped service' do
      k = kommando("kontena service start test-1")
      expect(k.run).to be_truthy
      sleep 1
      k = run("kontena service show test-1")
      expect(k.out.scan('status: running').size).to eq(2)
    end

    it 'starts initialized service' do
      k = kommando("kontena service start test-2")
      expect(k.run).to be_truthy
      sleep 1
      k = run("kontena service show test-2")
      expect(k.out.scan('status: running').size).to eq(1)
    end
  end
end
