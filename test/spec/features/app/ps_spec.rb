require 'spec_helper'

describe 'app ps' do
  it "returns list" do
    with_fixture_dir('app/simple') do
      k = run('kontena app ps')
      expect(k.code).to eq(0)
      %w(lb nginx redis).each do |service|
        expect(k.out).to match(/#{service}/)
      end
    end
  end
end
