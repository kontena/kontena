require 'kontena/command'

describe Kontena::Command do
  let(:subject) { described_class.new('kontena') }

  context 'for a command that raises RuntimeError without including Kontena::Cli::Common' do
    let(:command_class) { Class.new(Kontena::Command) do
      def execute
        fail 'test'
      end
    end}

    subject { command_class.new('test') }

    it 'logs an error and aborts' do
      expect{subject.run([])}.to raise_error(SystemExit).and output(/\[error\] RuntimeError : test\s+See .* or run the command again with environment DEBUG=true set to see the full exception/m).to_stderr
    end

    context 'with DEBUG' do
      before do
        allow(Kontena).to receive(:debug?).and_return(true)
      end

      it 'lets the error raise through' do
        expect{subject.run([])}.to raise_error(RuntimeError, 'test')
      end

    end
  end

  context 'for a command that raises StandardError without including Kontena::Cli::Common' do
    let(:command_class) { Class.new(Kontena::Command) do
      def execute
        raise Kontena::Errors::StandardError.new(404, "Not Found")
      end
    end}

    subject { command_class.new('test') }

    it 'logs an error and aborts' do
      expect{subject.run([])}.to raise_error(SystemExit).and output(" [error] 404 : Not Found\n").to_stderr
    end

    context 'with DEBUG' do
      before do
        allow(Kontena).to receive(:debug?).and_return(true)
      end

      it 'lets the error raise through' do
        expect{subject.run([])}.to raise_error(Kontena::Errors::StandardError)
      end
    end
  end
end
