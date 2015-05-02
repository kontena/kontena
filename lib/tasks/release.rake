

namespace :release do
  VERSION = File.read('VERSION')
  NAME = 'kontena-agent'
  DOCKER_NAME = 'kontena/agent'
  DOCKER_VERSIONS = ['latest', VERSION.match(/(\d+\.\d+)/)[1]]

  task :build => :environment do
    sh('mkdir -p build')
    sh('rm -rf build/ubuntu/')
    sh('docker pull ubuntu:trusty')
    sh("docker build -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker tag -f #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
    sh('cp -ar packaging/ubuntu build/')
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/DEBIAN/control")
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/kontena-weave/DEBIAN/control")

    sh("cd build/ubuntu && dpkg-deb -b #{NAME} . && dpkg-deb -b kontena-weave .")
  end

  task :upload => :environment do
    bintray_user = ENV['BINTRAY_USER']
    bintray_key = ENV['BINTRAY_KEY']
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
    sh("curl -T ./release/#{NAME}_#{VERSION}_all.deb -u#{bintray_user}:#{bintray_key} https://api.bintray.com/content/kontena/kontena/#{NAME}/#{VERSION}/#{NAME}-#{VERSION}_all.deb")
  end
end