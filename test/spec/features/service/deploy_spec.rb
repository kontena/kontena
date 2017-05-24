require 'spec_helper'

describe 'service deploy' do
  it 'deploys a service' do
    run("kontena service create test-1 redis:3.0")
    k = kommando("kontena service deploy test-1")
    expect(k.run).to be_truthy

    run("kontena service rm --force test-1")
  end

  context "For a service that fails to deploy" do
    before do
      k = run("kontena service create -v /dev/null/wtf:/dev/wtf test-fail redis")
      expect(k.code).to eq(0), k.out
    end

    after do
      k = run("kontena service rm --force test-fail")
      fail k.out unless k.code == 0
    end

    it "fails to deploy with an error" do
      k = run("kontena service deploy test-fail")

      expect(k.code).not_to eq(0), k.out

      expect(k.out).to match /halting deploy of .+, one or more instances failed/
      expect(k.out).to match /Failed to deploy instance .+ to node .+: GridServiceInstanceDeployer::ServiceError: .*stat \/dev\/null\/wtf: not a directory/
    end
  end
end
