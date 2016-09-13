name "kontena-cli"
default_version File.read('../VERSION').strip
dependency "ruby"
dependency "rubygems"
dependency "libxml2"
dependency "libxslt"
build do
  gem "install nokogiri -v 1.6.8 --no-ri --no-doc"
  gem "install kontena-cli -v #{default_version} --no-ri --no-doc"
  copy "wrappers/sh/kontena", "/usr/local/bin/kontena"
  command "chmod +x /usr/local/bin/kontena"
end
