
describe 'kontena service health_check' do
  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/healthcheck') do
        run! 'kontena stack build --no-push'
      end
    end
  
    let(:stack_name) { 'healthcheck-test' }

    before(:each) do
      with_fixture_dir('stack/healthcheck') do
        run! "kontena stack install -n #{stack_name} -v health_status=#{health_status}"
      end
    end

    after(:each) do
      run! "kontena stack rm --force #{stack_name}"
    end

    def check_service_health(service = "#{stack_name}/server")
      out = ''

      until match = out.match(/health: (\w+)/)
        sleep 1
        k = run! "kontena service show #{service}"
        out = k.out
      end
      
      match[1]
    end

    context "returning HTTP status 200 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-200' }
      let(:health_status) { 200 }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'healthy'
      end
    end

    context "returning HTTP status 500 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-500' }
      let(:health_status) { 500 }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'unhealthy'
      end
    end

  end
end
