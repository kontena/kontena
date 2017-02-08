require 'spec_helper'

describe 'service deploy' do
  it 'deploys a service' do
    run("kontena service create test-1 redis:3.0")
    k = kommando("kontena service deploy test-1")
    expect(k.run).to be_truthy

    run("kontena service rm --force test-1")
  end
end
