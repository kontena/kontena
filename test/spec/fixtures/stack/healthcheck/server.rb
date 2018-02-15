require 'webrick'

PORT = 8000
STATUS = 200

server = WEBrick::HTTPServer.new(
    :Port => PORT,
)

server.mount_proc '/' do |req, res|
    q = req.query()

    status = STATUS
    status = q['status'].to_i if q['status']
    location = q['location']

    res.status = status
    res['Location'] = location if location
    res.body = "Response status is #{status}\n"
end

trap 'TERM' do server.shutdown end

server.start
