require 'spec_helper'

describe 'stack list' do
  it "returns an empty list" do
    k = run 'kontena stack ls'
    expect(k.code).to eq(0)
    expect(k.out.lines.size).to eq(1)
  end

  it "returns an installed stack" do
    with_fixture_dir("stack/simple") do
      run 'kontena stack install --no-deploy'
    end
    k = run 'kontena stack ls'
    expect(k.code).to eq(0)
    expect(k.out.lines.size).to eq(2)
    expect(k.out.match(/simple.*test\/simple:.*initialized/)).to be_truthy
    run 'kontena stack rm --force simple'
  end
end
