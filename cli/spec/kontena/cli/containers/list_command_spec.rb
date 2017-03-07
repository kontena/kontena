require 'kontena/cli/grid_options'
require "kontena/cli/containers/list_command"

describe Kontena::Cli::Containers::ListCommand do
  include ClientHelpers

  context "for a single container with logs" do

    it "fetches containers" do
      expect(client).to receive(:get).with('containers/test-grid?').and_return({'containers' => []})

      subject.run([])
    end
  end
end
