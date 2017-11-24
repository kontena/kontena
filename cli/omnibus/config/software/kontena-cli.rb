name "kontena-cli"
license "Apache-2.0"
skip_transitive_dependency_licensing true # XXX: assumes bundler is installed within build
default_version File.read('../VERSION').strip
source path: "./wrappers"
dependency "ruby"
dependency "rubygems"
dependency "libxml2"
dependency "libxslt"
whitelist_file "./wrappers/sh/kontena"
build do
  gem "install rb-readline -v 0.5.4 --no-ri --no-doc"
  gem "install nokogiri -v 1.6.8 --no-ri --no-doc"
  gem "install kontena-cli -v #{default_version} --no-ri --no-doc"
  gem "install kontena-plugin-cloud --no-ri --no-doc"
  copy "sh/kontena", "#{install_dir}/bin/kontena"
end
