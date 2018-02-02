describe 'service link' do
  after(:each) do
    run "kontena service unlink simple/bar test-1"
    run "kontena service unlink test-1 simple/redis"
    run "kontena service unlink test-1 test2"
    sleep(1) unless %w(test-1 test-2 simple).map do |s|
      run("kontena service rm --force %s" % s).code
    end.all?(&:zero?)
  end

  it 'links service to target' do
    run "kontena service create test-1 redis:3.0"
    run "kontena service create test-2 redis:3.0"
    run! "kontena service link test-1 test-2"
    k = run! "kontena service show test-1"
    expect(k.out.match(/^\s+- test-2\s*$/)).to be_truthy
  end

  it 'links service to stack service' do
    with_fixture_dir("stack/simple") do
      run! 'kontena stack install --no-deploy'
    end
    run! "kontena service create test-1 redis:3.0"
    run! "kontena service link test-1 simple/redis"
    k = run! "kontena service show test-1"
    expect(k.out.match(/^\s+\- simple\/redis\s*$/)).to be_truthy
  end

  it 'links stack service with existing links to service' do
    with_fixture_dir("stack/links") do
      run! 'kontena stack install --no-deploy links.yml'
    end
    run! "kontena service create test-1 redis:3.0"
    run! "kontena service link simple/bar test-1"
    k = run! "kontena service show simple/bar"
    expect(k.out.match(/^\s+\- test-1\s*$/)).to be_truthy
  end

  it 'returns error if target does not exist' do
    run! "kontena service create test-1 redis:3.0"
    k = run "kontena service link test-1 foo"
    expect(k.code).not_to eq(0)
  end
end
