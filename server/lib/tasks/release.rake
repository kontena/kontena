

namespace :release do
  VERSION = File.read('VERSION').strip
  NAME = 'kontena-server'
  DOCKER_NAME = 'kontena/server'
  DOCKER_VERSIONS = ['latest', VERSION.match(/(\d+\.\d+)/)[1]]
  BINTRAY_USER = ENV['BINTRAY_USER']
  BINTRAY_KEY = ENV['BINTRAY_KEY']

  desc 'Build ubuntu package'
  task :build_ubuntu => :environment do
    rev = ENV['REV']
    raise ArgumentError.new('You must define REV') if rev.blank?

    sh('mkdir -p build')
    sh('rm -rf build/ubuntu/')
    sh('cp -ar packaging/ubuntu build/')
    sh("sed -i \"s/VERSION/#{VERSION}-#{rev}/g\" build/ubuntu/#{NAME}/DEBIAN/control")
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/DEBIAN/postinst")
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/etc/init/kontena-server-api.conf")
    sh("cd build/ubuntu && dpkg-deb -b #{NAME} .")
  end

  desc 'Build docker image'
  task :build_docker => :environment do
    sh("docker rmi #{DOCKER_NAME}:#{VERSION} || true")
    sh("docker build --no-cache --pull -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker rmi #{DOCKER_NAME}:#{v} || true")
      sh("docker tag #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Build all'
  task :build => [:build_ubuntu, :build_docker] do
  end

  desc 'Upload ubuntu package'
  task :push_ubuntu => :environment do
    rev = ENV['REV']
    raise ArgumentError.new('You must define REV') if rev.blank?
    repo = ENV['REPO'] || 'kontena'
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("curl -T ./release/#{NAME}_#{VERSION}-#{rev}_all.deb -u#{BINTRAY_USER}:#{BINTRAY_KEY} 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/#{NAME}-#{VERSION}-#{rev}_all.deb;deb_distribution=trusty;deb_component=main;deb_architecture=amd64'")
  end

  desc 'Upload docker image'
  task :push_docker do
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
  end
end
