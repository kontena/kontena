require 'spec_helper'

describe 'service list' do
  it 'shows empty list by default' do
    k = run("kontena service ls")
    expect(k.out.lines.size).to eq(1)
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
