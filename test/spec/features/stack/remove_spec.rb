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

  context "for a stack that has dependencies" do
    before do
      with_fixture_dir("stack/depends") do
        run 'kontena stack install'
      end
    end

    after do
      run 'kontena stack ls -q|grep twemproxy|xargs -n1 kontena stack rm --force'
    end

    it 'removes all the dependencies' do
      k = run 'kontena stack ls -q'
      expect(k.out.split(/[\r\n]/)).to match array_including(
        'twemproxy-redis_from_registry',
        'twemproxy-redis_from_yml',
        'twemproxy'
      )

      k = run 'kontena stack rm --force twemproxy'
      expect(k.code).to eq 0

      k = run 'kontena stack ls -q'
      expect(k.out).not_to match /twemproxy-redis_from_registry/
      expect(k.out).not_to match /twemproxy-redis_from_yml/
      expect(k.out).not_to match /twemproxy/
    end
  end
end
