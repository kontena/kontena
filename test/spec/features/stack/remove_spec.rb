require 'spec_helper'

describe 'stack remove' do
  after(:each) do
    run 'kontena stack rm --force simple'
  end

  it "removes a stack" do
    with_fixture_dir("stack/simple") do
      run 'kontena stack install --no-deploy'
    end
    k = run "kontena stack rm --force simple"
    expect(k.code).to eq(0)
    k = run "kontena stack show simple"
    expect(k.code).not_to eq(0)
  end

  it "prompts without --force" do
    with_fixture_dir("stack/simple") do
      run 'kontena stack install --no-deploy'
    end
    k = kommando 'kontena stack rm simple', timeout: 5
    k.out.on "To proceed, type" do
      sleep 0.5
      k.in << "simple\r"
    end
    k.run
    expect(k.code).to eq(0)
  end
end
