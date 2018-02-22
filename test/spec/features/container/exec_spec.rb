describe 'container exec' do

  it 'executes command in a given container' do
    id = container_id('kontena-agent')
    expect(id).not_to be_nil

    k = kommando("kontena container exec #{id} -- ls -la")
    expect(k.run).to be_truthy
    expect(k.out).to include("Gemfile.lock")
  end

  it 'exits with error if command fails' do
    id = container_id('kontena-agent')
    expect(id).not_to be_nil

    k = kommando("kontena container exec #{id} -- ls -l /nonexist")
    expect(k.run).to be_truthy
    expect(k.code).to_not eq 0
    expect(k.out).to include("/nonexist: No such file or directory")
  end

  it 'exits with command error' do
    id = container_id('kontena-agent')
    expect(id).not_to be_nil

    k = kommando("kontena container exec --shell #{id} exit 32")
    expect(k.run).to be_truthy
    expect(k.code).to eq 32
  end

  it 'fails if container does not exist' do
    k = run("kontena container exec invalid-id -- ls -la")
    expect(k.code).to eq(1)
    expect(k.out).to match /Error during WebSocket handshake: Unexpected response code: 404/
  end

  it 'runs a command inside a container with tty' do
    id = container_id('kontena-agent')
    k = kommando("kontena container exec -it #{id} sh")

    k.out.on("#") do
      k.in << "ls -la \r"
      k.out.on "Gemfile.lock" do
        sleep 0.1
        k.in << "exit\r"
      end
    end
    expect(k.run).to be_truthy
    expect(k.code).to be_zero, k.out
  end
end
