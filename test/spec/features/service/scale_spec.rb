require 'spec_helper'

describe 'service scale' do
  it 'scales a service' do
    run("kontena service create test-1 redis:3.0")
    k = kommando("kontena service deploy test-1")
    expect(k.run).to be_truthy
    k = kommando("kontena service scale test-1 3")
    expect(k.run).to be_truthy

    run("kontena service rm --force test-1")
  end
end
