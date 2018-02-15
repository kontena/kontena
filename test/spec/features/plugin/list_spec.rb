require 'spec_helper'

describe 'plugin list' do
  it "returns list" do
    run!('kontena plugin ls')
    # TODO result check
  end
end
