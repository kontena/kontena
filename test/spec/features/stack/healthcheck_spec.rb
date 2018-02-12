
describe 'kontena service health_check' do
  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/healthcheck') do
        run! 'kontena stack build --no-push'
      end
    end

    before(:each) do
      with_fixture_dir('stack/healthcheck') do
        run! "kontena stack install -v health_status=#{health_status}"
      end
    end

    after(:each) do
      run! 'kontena stack rm --force healthcheck'
    end

    def check_service_health(service)
      out = ''

      until match = out.match(/health: (\w+)/)
        sleep 1
        k = run! "kontena service show #{service}"
        out = k.out
      end
      
      match[1]
    end

    context "returning HTTP status 200 for healthchecks" do
      let(:health_status) { 200 }

      it "has a healthy status" do
        expect(check_service_health('healthcheck/server')).to eq 'healthy'
      end
    end

    context "returning HTTP status 500 for healthchecks" do
      let(:health_status) { 500 }

      it "has a healthy status" do
        expect(check_service_health('healthcheck/server')).to eq 'unhealthy'
      end
    end

  end
end
