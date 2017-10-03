require 'spec_helper'

describe 'service exec' do

  before(:all) do
    run("kontena service create test-1 redis:3.0")
    run("kontena service deploy test-1")
  end

  after(:all) do
    run("kontena service rm --force test-1")
  end

  it 'runs a command inside a service' do
    k = kommando("kontena service exec test-1 hostname -s")
    expect(k.run).to be_truthy
    expect(k.out).to eq("test-1-1\r\n")
  end

  it 'exits with error if command fails' do
    k = kommando("kontena service exec test-1 ls -l /nonexist")
    k.run
    expect(k.code).to_not eq 0
    expect(k.out).to include("/nonexist: No such file or directory")
  end

  it 'exits with command error' do
    k = kommando("kontena service exec --shell test-1 exit 32")
    k.run
    expect(k.code).to eq(32)
  end

  it 'returns an error if command not found' do
    k = kommando("kontena service exec test-1 thisdoesnotexist")
    k.run
    expect(k.code).to eq(126)
  end

  describe '--tty' do
    it 'runs a command inside a service' do
      k = kommando("kontena service exec -it test-1 sh")

      k.out.on("#") do
        k.in << "ls -la /\r"
        k.out.on "lib64" do
          k.in << "exit\r"
        end
      end
      expect(k.run).to be_truthy
    end

    it 'runs a command with tty control input' do
      k = kommando("kontena service exec -it test-1 sh")

      k.out.on("#") do
        k.in << "sleep 10 && echo ok\r"
        sleep 0.1
        k.in << "\x03"
        sleep 0.1
        k.in << "\x04"
      end

      expect(k.run).to be_truthy
      expect(k.out).to match /\^C/
    end

    it 'runs a command with non-ascii input' do
      k = kommando("kontena service exec -it test-1 sh")

      k.out.on("#") do
        k.in << "echo f\u00e5\u00e5 | LANG=C.UTF-8 rev\r"
        k.out.on("#") do
          k.in << "exit\r"
        end
      end

      expect(k.run).to be_truthy
      expect(k.out).to match /\u00e5\u00e5f/
    end
  end

  describe '--interactive' do
    it 'runs a command with piped stdin' do
      k = kommando("$ echo beer | kontena service exec -i test-1 rev")
      expect(k.run).to be_truthy
      expect(k.out).to eq('reeb')
    end

    it 'runs a command with piped non-ascii stdin' do
      k = kommando("$ echo f\u00e5\u00e5 | kontena service exec -i test-1 sh -c 'LANG=C.UTF-8 rev'")
      expect(k.run).to be_truthy
      expect(k.out).to eq("\u00e5\u00e5f")
    end
  end

  context 'with multiple instances' do
    before(:all) do
      run("kontena service scale test-1 2")
    end

    after(:all) do
      run("kontena service scale test-1 1")
    end

    it 'runs a command inside a service on a given instances' do
      k = kommando("kontena service exec --instance 2 test-1 hostname -s")
      expect(k.run).to be_truthy
      expect(k.out).to eq("test-1-2\r\n")
    end


    it 'runs a command on every instance with --all' do
      k = kommando("kontena service exec --all --silent test-1 hostname -s")
      expect(k.run).to be_truthy
      expect(k.out).to eq("test-1-1\r\ntest-1-2\r\n")
    end

    it 'fails early if running a command on every instances with --all fails' do
      k = kommando("kontena service exec --all --silent --shell test-1 hostname -s && false")
      expect(k.run).to be_truthy
      expect(k.code).to_not eq 0
      expect(k.out).to eq("test-1-1\r\n")
    end

    it 'keeps going if running a command on every instances with --all --skip' do
      k = kommando("kontena service exec --all --skip --silent --shell test-1 hostname -s && false")
      expect(k.run).to be_truthy
      expect(k.code).to_not eq 0
      expect(k.out).to eq("test-1-1\r\ntest-1-2\r\n")
    end
  end
end
