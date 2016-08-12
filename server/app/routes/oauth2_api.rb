require 'json'
require 'uri'

module OAuth2Api
  JSON_MIME        = 'application/json'.freeze
  FORM_MIME        = 'application/x-www-form-urlencoded'.freeze
  TEXT_MIME        = 'text/plain'.freeze
  HTML_MIME        = 'text/html'.freeze
  ACCEPT           = 'Accept'.freeze
  CONTENT_TYPE     = 'Content-Type'.freeze
  ENV_CONTENT_TYPE = 'HTTP_CONTENT_TYPE'.freeze
  ENV_ACCEPT       = 'HTTP_ACCEPT'.freeze
  SEMICOLON        = ';'.freeze

  module Common
    def params_from_anywhere
       params = 
         case request_content_type
         when JSON_MIME then JSON.parse(request.body.read)
         when FORM_MIME then URI.decode_www_form(request.body.read)
         else
           request.params
         end
       params.each { |k,v| params[k] = nil if v.to_s == BLANK}
       params
    rescue
      mime_halt(400, 'invalid_request', 'Invalid parameters')
      nil
    end

    def request_accept
      strip_charset(request.env[ENV_ACCEPT])
    end

    def request_content_type
      strip_charset(request.env[ENV_CONTENT_TYPE])
    end

    def strip_charset(header_str)
      header_str.to_s.split(SEMICOLON).first
    end

    def want_json?
      request_accept == JSON_MIME || request_content_type == JSON_MIME
    end

    def want_html?
      request_accept == HTML_MIME
    end

    def want_form?
      request_accept == FORM_MIME
    end

    def want_text?
      request_accept == TEXT_MIME
    end

    def mime_halt(status, error, error_description=nil)
      response.status = 400
      msg = { error: error, error_description: error_description }
      if want_json?
        response.headers[CONTENT_TYPE] = JSON_MIME
        response.write(msg.to_json)
      elsif want_form?
        response.headers[CONTENT_TYPE] = FORM_MIME
        response.write(URI.encode_www_form(msg))
      elsif want_text?
        response.headers[CONTENT_TYPE] = TEXT_MIME
        response.write("error:#{msg[:error]};error_description:#{msg[:error_description]}")
      else
        response.headers[CONTENT_TYPE] = HTML_MIME
        response.write("<html><head><title>Error</title></head><body><h3>Error</h3><p><b>#{msg[:error]}</b> #{msg[:error_description]}</p></body></html>")
      end
      request.halt
    end
  end
end

Dir[File.expand_path('../oauth2/*.rb', __FILE__)].each { |f| require f }
