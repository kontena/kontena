describe 'container exec' do
  def container_id
    k = run("kontena container list")
    k.out.match(/^.* (.+\/kontena-agent) .*/)[1]
  end

  it 'executes command in a given container' do 
    id = container_id
    expect(id).not_to be_nil

    k = kommando("kontena container exec #{id} ls -la")
    expect(k.run).to be_truthy
    expect(k.out).to include("Gemfile.lock")
  end

  it 'returns error if container does not exist' do 
    k = run("kontena container exec invalid-id")
    expect(k.code).to eq(1)
  end

  it 'runs a command inside a container with tty' do
    id = container_id
    k = kommando("kontena container exec -it #{id} sh")
    
    k.out.on("#") do
      k.in << "ls -la \r"
      k.out.on "Gemfile.lock" do 
        sleep 0.1
        k.in << "exit\r"
      end
    end
    expect(k.run).to be_truthy
  end
end