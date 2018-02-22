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
  env = with_standard_compiler_flags(with_embedded_path)
  gem "install rb-readline -v 0.5.4 -N", env: env
  gem "install nokogiri -v 1.8.2 -N", env: env
  gem "build kontena-cli.gemspec", env: env, cwd: File.expand_path('..', Omnibus::Config.project_root)
  gem "install -N kontena-cli-%s.gem" % default_version, env: env, cwd: File.expand_path('..', Omnibus::Config.project_root)
  gem "install kontena-plugin-cloud -N", env: env
  copy "sh/kontena", "#{install_dir}/bin/kontena"
end