Gem::Specification.new do |s|
  s.name          = 'kontena-lib'
  s.version       = '1.4.0.dev'
  s.summary       = "Kontena libraries"
  s.authors       = ["Kontena, Inc"]
  s.email         = ["info@kontena.io"]
  s.description   = "Common code shared by Kontena components"
  s.homepage      = "https://www.kontena.io"
  s.license       = "Apache-2.0"

  s.executables   = []
  s.require_paths = ['lib']

  s.add_development_dependency "websocket-driver", "~> 0.6.5"
end
