describe 'container logs' do
  it 'inspects a given container' do
    id = container_id('kontena-agent')
    expect(id).not_to be_nil

    k = kommando("kontena container logs #{id}")
    expect(k.run).to be_truthy
  end

  it 'returns error if container does not exist' do
    k = run("kontena container logs invalid-id")
    expect(k.code).to eq(1)
  end
end