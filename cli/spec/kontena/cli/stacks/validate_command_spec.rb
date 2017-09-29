require "kontena/cli/stacks/upgrade_command"

describe Kontena::Cli::Stacks::UpgradeCommand do

  include ClientHelpers
  include RequirementsHelper
  include FixturesHelpers

  context 'without dependencies' do
    before do
      [:read, :exist?].each do |meth|
        allow(File).to receive(meth).with(fixture_path('kontena_v3.yml')).and_call_original
        allow(File).to receive(meth).with(fixture_path('docker-compose_v2.yml')).and_call_original
      end
    end

    it 'validates a yaml file' do
      expect{Kontena.run!('stack', 'validate', fixture_path('kontena_v3.yml'))}.not_to exit_with_error
      expect{Kontena.run!('stack', 'validate', fixture_path('kontena_v3.yml'))}.to output(/stack:.*version:.*services:.*variables:/m).to_stdout
    end

    context '--online' do
      it 'validates a yaml file' do
        expect{Kontena.run!('stack', 'validate', '--online', fixture_path('kontena_v3.yml'))}.to output(/stack:.*version:.*services:.*variables:/m).to_stdout
      end
    end

  end

  context 'with dependencies' do
    before do
      Dir.glob(File.join(File.dirname(fixture_path('stack-with-dependencies.yml')), 'stack-with-dependencies*yml')).each do |file|
        [:read, :exist?].each do |meth|
          allow(File).to receive(meth).with(file).and_call_original
        end
      end
    end

    it 'validates all depended yaml files' do
      output = OutputHelpers::CaptureStdoutLines.capture(proc {Kontena.run!('stack', 'validate', fixture_path('stack-with-dependencies.yml'))})
      expect{Kontena.run!('stack', 'validate', fixture_path('stack-with-dependencies.yml'))}.not_to exit_with_error
      expect(output.select { |line| line.start_with?('---') }.size).to eq 4
      expect(output).to include('stack: user/depstack1')
      expect(output).to include('stack: user/depstack1child1')
      expect(output).to include('stack: user/depstack1child1child1')
      expect(output).to include('stack: user/depstack1child2')
      expect(output.select { |line| line.start_with?('stack') }.size).to eq 4
    end

    describe '--dependency-tree' do
      let(:expectation) do
        {
          "name" => "depstack1",
          "stack" => /stack-with-dependencies.yml$/,
          "depends" => [
            {
              "name" => "dep_1",
              "stack" => /stack-with-dependencies-dep-1.yml$/,
              "variables" => {},
              "depends" => [
                {
                  "name" => "dep_1",
                  "stack" => /stack-with-dependencies-dep-1-1.yml$/,
                  "variables" => {
                    "dep_var" => 2
                  }
                }
              ]
            },
            {
              "name" => "dep_2",
              "stack" => /stack-with-dependencies-dep-2.yml$/,
              "variables" => {
                "dep_var" => 1
              }
            }
          ]
        }
      end

      it 'outputs the dependency tree' do
        output = OutputHelpers::CaptureStdoutLines.capture(proc {Kontena.run!('stack', 'validate', '--dependency-tree', fixture_path('stack-with-dependencies.yml'))})
        yaml = ::YAML.safe_load(output.join("\n"))
        expect(yaml).to match hash_including(expectation)
      end
    end
  end
end
