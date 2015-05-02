

namespace :release do
  VERSION = File.read('VERSION')
  NAME = 'kontena-server'
  DOCKER_NAME = 'kontena/server'
  DOCKER_VERSIONS = ['latest', VERSION.match(/(\d+\.\d+)/)[1]]
  BINTRAY_USER = ENV['BINTRAY_USER']
  BINTRAY_KEY = ENV['BINTRAY_KEY']

  task :build_ubuntu => :environment do
    sh('mkdir -p build')
    sh('rm -rf build/ubuntu/')
    sh('cp -ar packaging/ubuntu build/')
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/DEBIAN/control")
    sh("cd build/ubuntu && dpkg-deb -b #{NAME} .")
  end

  task :build_docker => :environment do
    sh('docker pull ubuntu:trusty')
    sh("docker build -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker tag -f #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
  end

  task :build => [:build_ubuntu, :build_docker] do
  end

  task :upload => :environment do
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
    sh("curl -T ./release/#{NAME}_#{VERSION}_all.deb -u#{BINTRAY_USER}:#{BINTRAY_KEY} https://api.bintray.com/content/kontena/kontena/#{NAME}/#{VERSION}/#{NAME}-#{VERSION}_all.deb")
  end
end