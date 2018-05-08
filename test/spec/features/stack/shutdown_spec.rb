require 'net/http'

describe 'kontena service shutdown' do
  include ServiceHelper

  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/shutdown-test') do
        run! 'kontena stack build --no-push'
      end
    end

    context "using ungraceful shutdown to fail requests" do
      before(:all) do
        with_fixture_dir('stack/shutdown-test') do
          run! "kontena stack install -n shutdown-test-fail -v trap=false"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force shutdown-test-fail'
      end

      describe "after re-deploying the server" do
        before do
          run! 'kontena service deploy --force shutdown-test-fail/server'
        end

        it "will result in client errors" do
          events = service_events('shutdown-test-fail/client')

          expect(events.select{|e| e[:type] == 'instance_crash'}).to_not eq([]), service_logs('shutdown-test-fail/client').join
        end
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

        pending "does not result in any client errors" do
          events = service_events('shutdown-test-graceful/client')

          expect(events.select{|e| e[:type] == 'instance_crash'}).to eq([]), service_logs('shutdown-test-graceful/client').join
        end
      end
    end

    context "using graceful shutdown without a healthcheck" do
      before(:all) do
        with_fixture_dir('stack/shutdown-test') do
          run! "kontena stack install -n shutdown-test-nohealthcheck -v graceful_shutdown=true -v healthcheck=false"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force shutdown-test-nohealthcheck'
      end

      describe "after re-deploying the server" do
        before do
          run! 'kontena service deploy --force shutdown-test-nohealthcheck/server'
        end

        it "does not result in any client errors" do
          events = service_events('shutdown-test-nohealthcheck/client')

          expect(events.select{|e| e[:type] == 'instance_crash'}).to eq([]), service_logs('shutdown-test-nohealthcheck/client').join
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

          expect(events.select{|e| e[:type] == 'instance_crash'}).to eq([]), service_logs('shutdown-test-delay/client').join
        end
      end
    end
  end
end
