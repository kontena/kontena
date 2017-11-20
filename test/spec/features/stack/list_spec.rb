require 'spec_helper'

describe 'stack list' do
  after do
    run('kontena stack rm --force simple')
  end

  it "returns an empty list with headers" do
    k = run 'kontena stack ls'
    expect(k.code).to eq(0)
    expect(k.out.lines.size).to eq(1)
    expect(k.out).to match(/NAME.*STACK.*STATE/)
  end

  it "returns an installed stack" do
    with_fixture_dir("stack/simple") do
      run 'kontena stack install --no-deploy'
    end
    k = run 'kontena stack ls'
    expect(k.code).to eq(0)
    expect(k.out.lines.size).to eq(2)
    expect(k.out.match(/simple.*test\/simple:.*initialized/)).to be_truthy
  end

  context 'quiet mode' do
    it "returns an installed stack name" do
      with_fixture_dir("stack/simple") do
        run 'kontena stack install --no-deploy'
      end
      k = run 'kontena stack ls -q'
      expect(k.code).to eq(0)
      expect(k.out.lines.size).to eq(1)
      expect(k.out.strip).to eq "simple"
    end

    it "returns nothing when there are no stacks" do
      k = run 'kontena stack ls -q'
      expect(k.code).to eq(0)
      expect(k.out.lines.size).to eq(0)
    end
  end
end
