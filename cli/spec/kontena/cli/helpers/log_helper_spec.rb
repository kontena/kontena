require "kontena/cli/helpers/log_helper"

describe Kontena::Cli::Helpers::LogHelper do

  let(:described_class) do
    Class.new do
      include Kontena::Cli::Helpers::LogHelper

      def buffer
        @buffer
      end
    end
  end

  describe '#buffered_log_json' do
    it 'returns has on valid json' do
      chunk = {"foo" => "bar"}
      log = subject.buffered_log_json(chunk.to_json)
      expect(log).to eq(chunk)
    end

    it 'combines multi part json chunks to valid json' do
      chunk1 = '{"foo": "'
      chunk2 = 'bar'
      chunk3 = '"}'
      log = subject.buffered_log_json(chunk1)
      expect(log).to be_nil
      log = subject.buffered_log_json(chunk2)
      expect(log).to be_nil
      log = subject.buffered_log_json(chunk3)
      expect(log).to eq({"foo" => "bar"})
    end

    it 'handles big log messages' do
      chunk1 = '{"foo": "' << "lol" * 10000
      chunk2 = 'lol'
      chunk3 = 'lol"}'
      log = subject.buffered_log_json(chunk1)
      expect(log).to be_nil
      log = subject.buffered_log_json(chunk2)
      expect(log).to be_nil
      log = subject.buffered_log_json(chunk3)
      expect(log).to eq(JSON.parse(chunk1 + chunk2 + chunk3))
    end

    it 'does not append to buffer if buffer is empty and chunk has just whitespace' do
      log = subject.buffered_log_json(' ')
      expect(log).to be_nil
      expect(subject.buffer).to eq('')
    end

    it 'returns nil on invalid json' do
      log = subject.buffered_log_json('{"foo": "')
      expect(log).to be_nil
    end
  end
end
