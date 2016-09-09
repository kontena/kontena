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
      run("kontena service deploy test-1")

      k = kommando("kontena service logs -t test-1", timeout: 60)
      k.out.on "Server started, Redis version 3.0" do
        deployed = true
      end
      k.run

      run("kontena service rm --force test-1")
      expect(deployed).to be_truthy
    end
  end

  context 'scale' do
    it 'scales service' do
      run("kontena service create test-1 redis:3.0")
      run("kontena service deploy test-1")

      k = kommando("kontena grid logs -t -c kontena-agent", timeout: 60)
      k.out.on "service started: test-1-1" do
        k.in << ctrl_c
      end
      k.run
      run("kontena service scale test-1 3")
      scaled = false
      k = kommando("kontena grid logs -t -c kontena-agent", timeout: 60)
      k.out.on "service started: test-1-3" do
        scaled = true
        k.in << ctrl_c
      end
      k.run
      run("kontena service create test-1 redis:3.0")
      expect(scaled).to be_truthy
    end
  end
end
