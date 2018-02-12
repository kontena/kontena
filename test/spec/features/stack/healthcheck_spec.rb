require 'net/http'

describe 'kontena service health_check' do
  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/healthcheck') do
        run! 'kontena stack build --no-push'
      end
    end
  
    let(:stack_name) { 'healthcheck-test' }
    let(:health_status) { 200 }
    let(:health_location) { '' }

    before(:each) do
      with_fixture_dir('stack/healthcheck') do
        run! "kontena stack install -n #{stack_name} -v health_status=#{health_status} -v health_location=#{health_location}"
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
    
    def check_lb_response_code(url="http://localhost/health")
      response = Net::HTTP.get_response(URI(url))
      response.code.to_i
    end

    context "returning HTTP 200 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-200' }
      let(:health_status) { 200 }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'healthy'
      end

      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 302 => 200 redirect for healthchecks" do
      let(:stack_name) { 'healthcheck-test-302-200' }
      let(:health_status) { 302 }
      let(:health_location) { '/health?status=200' }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'healthy'
      end
      
      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 302 => 500 redirect for healthchecks" do
      let(:stack_name) { 'healthcheck-test-302-500' }
      let(:health_status) { 302 }
      let(:health_location) { '/health?status=500' }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'healthy'
      end
      
      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 500 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-500' }
      let(:health_status) { 500 }

      it "has a healthy status" do
        expect(check_service_health()).to eq 'unhealthy'
      end
    end

      it "returns HTTP 503 via the LB" do
        expect(check_lb_response_code).to eq 503
      end
    end
  end
end
