require 'net/http'

describe 'kontena service health_check' do
  context 'for a http test service' do
    before(:all) do
      with_fixture_dir('stack/healthcheck') do
        run! 'kontena stack build --no-push'
      end
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
    
    def check_lb_response_code(url = 'http://localhost/', retry_503: 5)
      uri = URI(url)
      count = 0

      loop do
        response = Net::HTTP.get_response(uri)
        status = response.code.to_i

        puts "GET #{uri} => #{status}"

        if status == 503 && ((count += 1) < retry_503)
          # LB can return 503 temporarily during configuration, retry to make sure it's stable before returning it
          sleep 1
        else
          return status
        end
      end 
    end

    context "returning HTTP 200 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-200' }

      before(:all) do
        with_fixture_dir('stack/healthcheck') do
          run! "kontena stack install -n healthcheck-test-200 -v health_status=200"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force healthcheck-test-200'
      end

      it "has a healthy status" do
        expect(check_service_health('healthcheck-test-200/server')).to eq 'healthy'
      end

      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 302 => 200 redirect for healthchecks" do
      let(:stack_name) { 'healthcheck-test-302-200' }

      before(:all) do
        with_fixture_dir('stack/healthcheck') do
          run! "kontena stack install -n healthcheck-test-302-200 -v health_status=302 -v health_location=/health?status=200"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force healthcheck-test-302-200'
      end

      it "has a healthy status" do
        expect(check_service_health('healthcheck-test-302-200/server')).to eq 'healthy'
      end
      
      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 302 => 500 redirect for healthchecks" do
      let(:stack_name) { 'healthcheck-test-302-500' }

      before(:all) do
        with_fixture_dir('stack/healthcheck') do
          run! "kontena stack install -n healthcheck-test-302-500 -v health_status=302 -v health_location=/health?status=500"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force healthcheck-test-302-500'
      end

      it "has a healthy status" do
        expect(check_service_health('healthcheck-test-302-500/server')).to eq 'healthy'
      end
      
      it "returns HTTP 200 via the LB" do
        expect(check_lb_response_code).to eq 200
      end
    end

    context "returning HTTP 500 for healthchecks" do
      let(:stack_name) { 'healthcheck-test-500' }
      before(:all) do
        with_fixture_dir('stack/healthcheck') do
          run! "kontena stack install -n healthcheck-test-500 -v health_status=500"
        end
      end
      after(:all) do
        run! 'kontena stack rm --force healthcheck-test-500'
      end
 
      it "has a healthy status" do
        expect(check_service_health('healthcheck-test-500/server')).to eq 'unhealthy'
      end

      it "returns HTTP 503 via the LB" do
        expect(check_lb_response_code(retry_503: 3)).to eq 503
      end
    end
  end
end
