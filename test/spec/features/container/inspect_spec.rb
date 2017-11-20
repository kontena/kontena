describe 'container inspect' do

  it 'inspects a given container' do
    id = container_id('kontena-agent')
    expect(id).not_to be_nil

    k = kommando("kontena container inspect #{id}")
    expect(k.run).to be_truthy
  end

  it 'returns error if container does not exist' do
    k = run("kontena container inspect invalid-id")
    expect(k.code).to eq(1)
  end
end