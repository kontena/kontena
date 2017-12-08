require "kontena/cli/stacks/upgrade_command"

describe Kontena::Cli::Stacks::UpgradeCommand do

  include ClientHelpers
  include RequirementsHelper
  include FixturesHelpers
  include OutputHelpers

  context 'without dependencies' do
    before do
      [:read, :exist?].each do |meth|
        allow(File).to receive(meth).with(fixture_path('kontena_v3.yml')).and_call_original
        allow(File).to receive(meth).with(fixture_path('docker-compose_v2.yml')).and_call_original
        allow(File).to receive(meth).with(fixture_path('stack-with-liquid.yml')).and_call_original
      end
    end

    it 'outputs interpolated YAML' do
      expect{Kontena.run!('stack', 'validate', fixture_path('stack-with-liquid.yml'))}.to output_yaml(
        'stack' => 'user/stackname',
        'version' => '0.1.1',
        'variables' => {
          'grid_name' => hash_including(
              'value' => 'validate stackname',
          ),
          'copies' => {
            'type' => 'integer',
            'value' => 5,
          }
        },
        'services' => hash_including(
          'service-1' => hash_including(
            'image' => 'foo:1',
          ),
        ),
      )
    end

    it 'outputs API JSON' do
      expect{Kontena.run!('stack', 'validate', '-v', 'copies=2', '--format=api-json', fixture_path('stack-with-liquid.yml'))}.to output_json(hash_including(
        'stack' => 'user/stackname',
        'version' => '0.1.1',
        'name' => 'stackname',
        'registry' => 'file://',
        'expose' => nil,
        'volumes' => [ ],
        'dependencies' => nil,
        'source' => a_string_matching(/.+/),
        'parent_name' => nil,
        'variables' => {
          'grid_name' => '{{ GRID }} stackname',
          'copies' => 2,
        },
        'services' => [
          hash_including(
            'name' => 'service-1',
            'image' => 'foo:1',
          ),
          hash_including(
            'name' => 'service-2',
            'image' => 'foo:2',
          ),
        ],
      ))
    end

    context '--online' do
      it 'validates a yaml file' do
        expect{Kontena.run!('stack', 'validate', '--online', fixture_path('kontena_v3.yml'))}.to output(/stack:.*version:.*services:/m).to_stdout
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
