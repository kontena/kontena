require "kontena/cli/helpers/exec_helper"

describe Kontena::Cli::Helpers::ExecHelper do

  include ClientHelpers

  let(:described_class) do
    Class.new do
      include Kontena::Cli::Helpers::ExecHelper
      def initialize(*args)
      end
    end
  end

  describe '#ws_url' do
    it 'returns an exec url for a container id' do
      expect(subject).to receive(:require_current_master).and_return(double(url: 'http://someurl/'))
      expect(subject.ws_url('abcd1234')).to eq 'ws://someurl/v1/containers/abcd1234/exec'
    end

    it 'also works when the url does not have a trailing slash' do
      expect(subject).to receive(:require_current_master).and_return(double(url: 'http://someurl'))
      expect(subject.ws_url('abcd1234')).to eq 'ws://someurl/v1/containers/abcd1234/exec'
    end

    context 'query params' do
      before(:each) do
        allow(subject).to receive(:require_current_master).and_return(double(url: 'http://someurl'))
      end

      it 'can add the interactive query param' do
        expect(subject.ws_url('abcd1234', interactive: true)).to eq 'ws://someurl/v1/containers/abcd1234/exec?interactive=true'
      end

      it 'can add the shell query param' do
        expect(subject.ws_url('abcd1234', shell: true)).to eq 'ws://someurl/v1/containers/abcd1234/exec?shell=true'
      end

      it 'can add both query params' do
        expect(subject.ws_url('abcd1234', shell: true, interactive: true)).to eq 'ws://someurl/v1/containers/abcd1234/exec?interactive=true&shell=true'
      end
    end
  end
end
