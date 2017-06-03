require 'spec_helper'

describe 'service exec' do

  before(:all) do
    run("kontena service create test-1 redis:3.0")
    run("kontena service deploy test-1")
  end

  after(:all) do
    run("kontena service rm --force test-1")
  end

  it 'runs a command inside a service' do
    k = kommando("kontena service exec test-1 hostname -s")
    expect(k.run).to be_truthy
    expect(k.out).to eq("test-1-1\r\n")
  end

  it 'returns an error if command not found' do
    k = kommando("kontena service exec test-1 thisdoesnotexist")
    k.run
    expect(k.code).to eq(126)
  end

  it 'runs a command inside a service on a given instances' do
    run("kontena service scale test-1 2")
    k = kommando("kontena service exec --instance 2 test-1 hostname -s")
    expect(k.run).to be_truthy
    expect(k.out).to eq("test-1-2\r\n")
    run("kontena service scale test-1 1")
  end

  it 'runs a command inside a service with tty' do
    k = kommando("kontena service exec -it test-1 sh")
    
    k.out.on("#") do
      k.in << "ls -la /\r"
      k.out.on "lib64" do 
        k.in << "exit\r"
      end
    end
    expect(k.run).to be_truthy
  end

  it 'runs a command on every instance with --all' do 
    run("kontena service scale test-1 2")
    k = kommando("kontena service exec --all --silent test-1 hostname -s")
    expect(k.run).to be_truthy
    expect(k.out).to eq("test-1-1\r\ntest-1-2\r\n")
    run("kontena service scale test-1 1")
  end
end