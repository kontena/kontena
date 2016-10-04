module RequestHelpers

  def self.included(base)
    base.plugin :json
    base.plugin :all_verbs
    base.plugin :default_headers, 'Content-Type'=>'application/json'
    base.plugin :render, cache: true, engine: 'json.jbuilder', views: 'app/views/v1'
    base.plugin :error_handler do |e|
      if e.is_a?(RpcClient::Error)
        { code: e.code, message: e.message, backtrace: e.backtrace }
      else
        response.status = 500
        log_message = "\n#{e.class} (#{e.message}):\n"
        log_message << "  " << e.backtrace.join("\n  ") << "\n\n" if e.backtrace
        puts log_message
        json = { message: 'Internal server error' }

        json
      end
    end
  end

  def parse_form_body
    body = request.body.read
    if body == ''
      {}
    else
      URI.decode_www_form(body)
    end
  rescue
    response.status = 400
    response.write("invalid_request")
    request.halt
  end

  def parse_json_body
    body = request.body.read
    if body == ''
      {}
    else
      JSON.parse(body)
    end
  rescue => exc
    response.status = 400
    response.write({error: 'Invalid json'}.to_json)
    request.halt
  end

  def halt_request(status, body = {})
    response.status = status
    response.write(body.to_json)
    request.halt
  end

  def test_env?
    ENV['RACK_ENV'].to_s == 'test'
  end

  def dev_env?
    ENV['RACK_ENV'].to_s == 'development'
  end
end
