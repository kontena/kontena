require 'spec_helper'

describe 'service logs' do
  before(:each) do
    run("kontena service create --instances 2 test-1 redis:3.0")
    run("kontena service deploy test-1")
  end

  after(:each) do
    run("kontena service rm --force test-1")
  end

  it 'displays service logs' do
    k = kommando("kontena service logs test-1")
    expect(k.run).to be_truthy
    expect(k.out.scan('The server is now ready to accept connections on port 6379').size).to eq(2)
  end

  context 'when passing instance number' do
    it 'diplays logs only from related service instance' do
      k = kommando("kontena service logs -i 1 test-1")
      expect(k.run).to be_truthy
      expect(k.out.scan('The server is now ready to accept connections on port 6379').size).to eq(1)
    end
  end
end
