namespace :release do
  VERSION = Gem::Version.new(File.read('VERSION').strip)
  DEB_NAME = 'kontena-cli'
  DOCKER_NAME = 'kontena/cli'
  if VERSION.prerelease?
    DOCKER_VERSIONS = ['edge']
    DEB_COMPONENT = 'edge'
  else
    DOCKER_VERSIONS = ['latest', VERSION.to_s.match(/(\d+\.\d+)/)[1]]
    DEB_COMPONENT = 'main'
  end

  desc 'Setup omnibus'
  task :setup_omnibus do
    Dir.chdir('omnibus') do
      sh("bundle install --binstubs")
    end
  end

  desc 'Build all'
  task :build => [:build_docker] do
  end

  desc 'Build omnibus package'
  task :build_omnibus do
    Dir.chdir('omnibus') do
      sh("bin/omnibus build kontena --log-level info")
    end
  end

  desc 'Build docker images'
  task :build_docker do
    sh("docker rmi #{DOCKER_NAME}:#{VERSION} || true")
    sh("docker build --build-arg CLI_VERSION=#{VERSION} --no-cache --pull -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker rmi #{DOCKER_NAME}:#{v} || true")
      sh("docker tag #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Push all'
  task :push => [:push_docker] do
  end

  desc 'Push docker images'
  task :push_docker => :build_docker do
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Upload ubuntu packages'
  task :push_omnibus_ubuntu do
    rev = ENV['REV'] || '1'
    repo = ENV['REPO'] || 'ubuntu'
    arch = ENV['ARCH'] || 'amd64'
    deb = "./omnibus/pkg/#{DEB_NAME}_*_#{arch}.deb"

    sh("curl --netrc -T #{deb} 'https://api.bintray.com/content/kontena/#{repo}/#{DEB_NAME}/#{VERSION}/pool/#{DEB_COMPONENT}/k/#{DEB_NAME}-#{VERSION}-#{rev}~xenial.deb;deb_distribution=xenial;deb_component=#{DEB_COMPONENT};deb_architecture=#{arch};publish=1'")
  end
end
