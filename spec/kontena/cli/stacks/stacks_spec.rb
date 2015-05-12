require_relative "../../../spec_helper"
require "kontena/cli/stacks/stacks"

module Kontena::Cli::Stacks
  describe Stacks do
    let(:settings) do
      {'server' => {'url' => 'http://kontena.test', 'token' => token}}
    end

    let(:token) do
      '1234567'
    end


    let(:services) do
      {
          'wordpress' => {
              'image' => 'wordpress:latest',
              'links' => ['mysql:db'],
              'ports' => ['80:80'],
              'instances' => 2,
              'deploy' => {
                  'strategy' => 'ha'
              }
          },
          'mysql' => {
              'image' => 'mysql:5.6',
              'stateful' => true
          }
      }
    end

    let(:client) do
      double
    end

    let(:options) do
      options = double({prefix: false, file: false})
    end

    describe '#deploy' do
      context 'when api_url is nil' do
        it 'raises error' do
          allow(subject).to receive(:settings).and_return({'server' => {}})
          expect{subject.deploy({})}.to raise_error(ArgumentError)
        end
      end

      context 'when token is nil' do
        it 'raises error' do
          allow(subject).to receive(:settings).and_return({'server' => {'url' => 'http://kontena.test'}})
          expect{subject.deploy({})}.to raise_error(ArgumentError)
        end
      end

      context 'when api url and token are valid' do
        before(:each) do
          allow(subject).to receive(:settings).and_return(settings)
          allow(YAML).to receive(:load).and_return(services)
          allow(File).to receive(:read)
          allow(subject).to receive(:find_service_by_name).and_return(nil)
          allow(subject).to receive(:create_service).and_return({'id' => 'kontena-test-mysql'},{'id' => 'kontena-test-wordpress'})
          allow(subject).to receive(:current_grid).and_return('1')
          allow(subject).to receive(:deploy_service).and_return(nil)
        end

        it 'reads ./kontena.yml file by default' do
          allow(subject).to receive(:settings).and_return(settings)

          expect(File).to receive(:read).with('./kontena.yml')
          expect(options).to receive(:file).once.and_return(false)
          subject.deploy(options)
        end

        it 'reads given yml file' do
          expect(options).to receive(:file).once.and_return('custom.yml')
          expect(File).to receive(:read).with('custom.yml')
          subject.deploy(options)
        end

        it 'uses current directory as service name prefix by default' do
          current_dir = '/kontena/tests/stacks'
          allow(Dir).to receive(:getwd).and_return(current_dir)
          expect(File).to receive(:basename).with(current_dir)
          subject.deploy(options)
        end

        it 'creates mysql service before wordpress' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          data = {:name =>"kontena-test-mysql", :image=>'mysql:5.6', :env=>nil, :container_count=>nil, :stateful=>true}
          expect(subject).to receive(:create_service).with('1234567', '1', data)

          subject.deploy(options)
        end

        it 'creates wordpress service' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")

          data = {
              :name =>"kontena-test-wordpress",
              :image=>"wordpress:latest",
              :env=>nil,
              :container_count=>2,
              :stateful=>false,
              :links=>[{:name=>"kontena-test-mysql", :alias=>"db"}],
              :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
          }
          expect(subject).to receive(:create_service).with('1234567', '1', data)

          subject.deploy(options)
        end

        it 'deploys services' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-mysql', {})
          expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-wordpress', {:strategy => 'ha'})
          subject.deploy(options)
        end


      end
    end
  end
end