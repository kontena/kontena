describe 'service unlink' do
  after(:each) do
    %w(test-1 test-2).each do |s|
      run "kontena service rm --force #{s}"
    end
  end

  it 'unlinks service to target' do
    run "kontena service create test-1 redis:3.0"
    run "kontena service create test-2 redis:3.0"
    run "kontena service link test-1 test-2"
    k = run "kontena service unlink test-1 test-2"
    expect(k.code).to eq(0)
    k = run "kontena service show test-1"
    expect(k.out.match(/^\s+- test-2\s*$/)).to be_falsey
  end

  it 'unlinks service from stack with existing links' do
    with_fixture_dir("stack/links") do
      run 'kontena stack install --no-deploy links.yml'
    end
    run "kontena service create test-1 redis:3.0"
    k = run "kontena service link simple/bar test-1"
    expect(k.code).to eq(0)
    k = run "kontena service show simple/bar"
    expect(k.out.match(/^\s+\- test-1\s*$/)).to be_truthy
    k = run "kontena service unlink simple/bar test-1"
    expect(k.out.match(/^\s+\- test-1\s*$/)).to be_falsey
  end

  it 'returns error if target does not exist' do
    run "kontena service create test-1 redis:3.0"
    k = run "kontena service unlink test-1 foo"
    expect(k.code).not_to eq(0)
  end
end
