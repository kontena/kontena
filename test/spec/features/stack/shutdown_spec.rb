require 'net/http'

describe 'kontena service shutdown' do
  include ServiceHelper

  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/shutdown-test') do
        run! 'kontena stack build --no-push'
      end
    end
    
    context "using graceful shutdown to close the listening socket" do
      before(:all) do
        with_fixture_dir('stack/shutdown-test') do
          run! "kontena stack install -n shutdown-test-graceful -v graceful_shutdown=true"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force shutdown-test-graceful'
      end

      describe "after re-deploying the server" do

        before do
          run! 'kontena service deploy --force shutdown-test-graceful/server'
        end

        it "does not result in any client errors" do
          events = service_events('shutdown-test-graceful/client')

          expect(events.select{|e| e[:type] == 'instance_exit'}).to be_empty
        end
      end
    end

    context "using delayed shutdown without closing the listening socket" do
      before(:all) do
        with_fixture_dir('stack/shutdown-test') do
          run! "kontena stack install -n shutdown-test-delay -v graceful_shutdown=false"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force shutdown-test-delay'
      end

      describe "after re-deploying the server" do

        before do
          run! 'kontena service deploy --force shutdown-test-delay/server'
        end

        it "does not result in any client errors" do
          events = service_events('shutdown-test-delay/client')

          expect(events.select{|e| e[:type] == 'instance_exit'}).to eq []
        end
      end
    end

  end
end
