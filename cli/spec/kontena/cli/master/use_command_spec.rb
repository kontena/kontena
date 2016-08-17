require_relative "../../../spec_helper"
require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#use' do
    it 'should update current master' do
      expect(subject).to receive(:current_master=).with('some_master')
      subject.run(['some_master'])
    end

    it 'should fetch grid list from master' do
      allow(subject).to receive(:require_token).and_return('token')
      expect(subject).to receive(:current_master=).with('some_master')
      expect(client).to receive(:get).with('grids')
      subject.run(['some_master'])
    end
  end
end
