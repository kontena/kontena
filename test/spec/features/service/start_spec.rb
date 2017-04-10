require 'spec_helper'

describe 'service start' do
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
    expect(k.out.scan('desired_state: running').size).to eq(1)
    expect(k.out.scan('status: running').size).to eq(1)
  end

  it 'starts initialized service' do
    k = kommando("kontena service start test-2")
    expect(k.run).to be_truthy
    sleep 1
    k = run("kontena service show test-2")
    expect(k.out.scan('desired_state: running').size).to eq(1)
  end
end
