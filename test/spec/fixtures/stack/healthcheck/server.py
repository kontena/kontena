import urllib.parse
import http.server
import os.path

PORT = 8000

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(url.query)
        
        if 'status' in query:
            status = int(query.get('status')[0])
        else:
            status = 200


        headers = {}
        
        if 'location' in query:
            location = query.get('location')[0]

            headers['Location'] = location

        self.respond(status, "Response status is {status}\n".format(status=status), headers=headers)
    
    def respond(self, status, body, headers={}):
        self.send_response(status)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', len(body))
        for header, value in headers.items():
            self.send_header(header, value)
        self.end_headers()

        self.wfile.write(body.encode('utf-8'))

def run(server_class=http.server.HTTPServer, handler_class=Handler):
    server_address = ('', PORT)
    httpd = server_class(server_address, handler_class)
    httpd.serve_forever()

if __name__ == '__main__':
    run()
