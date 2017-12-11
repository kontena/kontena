require 'kontena/cli/registry/create_command'

describe Kontena::Cli::Registry::CreateCommand do
  include ClientHelpers
  include OutputHelpers

  context "with an existing legacy registry service" do
    let :service do
      {
        'name' => 'registry',
      }
    end

    before do
      allow(client).to receive(:get).with('services/test-grid/registry').and_return(service)
    end

    it "does not create the registry" do
      expect{subject.run []}.to exit_with_error.and output(/Registry already exists/).to_stderr
    end
  end
end
