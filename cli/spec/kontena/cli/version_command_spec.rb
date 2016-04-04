require_relative "../../spec_helper"
require "kontena/cli/version_command"

describe Kontena::Cli::VersionCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:client).and_return(client)
    end

    it 'runs without errors' do
      subject.run([])
    end
  end
end
