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

  context 'option placement handling' do
    subject do
      Class.new(Kontena::Command) do
        parameter 'TESTPARAM', 'Test parameter'
        option '--long-only', 'LONGONLY', 'Option with long only'
        option ['--long-and-short', '-l'], :flag, 'Flag with short and long', default: false

        def execute
          { param: testparam, longopt: long_only, shortflag: long_and_short? }
        end
      end

    end

    it 'allows using options before parameters' do
      expect(subject.new('kontena').run(%w(-l --long-only longopt test))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: true
      )
      expect(subject.new('kontena').run(%w(--long-only longopt test))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: false
      )
      expect(subject.new('kontena').run(%w(--long-and-short test))).to match hash_including(
        param: 'test', longopt: nil, shortflag: true
      )
    end

    it 'allows using options after parameters' do
      expect(subject.new('kontena').run(%w(test -l --long-only longopt))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: true
      )
      expect(subject.new('kontena').run(%w(test --long-only longopt))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: false
      )
      expect(subject.new('kontena').run(%w(test --long-and-short))).to match hash_including(
        param: 'test', longopt: nil, shortflag: true
      )
    end

    it 'allows using options mixed with parameters' do
      expect(subject.new('kontena').run(%w(-l test --long-only longopt))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: true
      )
      expect(subject.new('kontena').run(%w(--long-and-short test --long-only longopt))).to match hash_including(
        param: 'test', longopt: 'longopt', shortflag: true
      )
    end

    context 'with double dash' do
      subject do
        Class.new(Kontena::Command) do
          parameter 'TESTPARAM ...', 'Test parameter'
          option '--opt', 'OPT', 'Option'

          def execute
            { param_list: testparam_list, opt: opt }
          end
        end
      end

      it 'does not parse options after -- double dash' do
        expect(subject.new('kontena').run(%w(--opt hello foo -- --bar hello))).to match hash_including(
          param_list: %w(foo --bar hello), opt: 'hello'
        )
      end
    end
  end
end
