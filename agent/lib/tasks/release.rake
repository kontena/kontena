

namespace :release do
  VERSION = File.read('VERSION').strip
  NAME = 'kontena-agent'
  DOCKER_NAME = 'kontena/agent'
  DOCKER_VERSIONS = ['latest', VERSION.match(/(\d+\.\d+)/)[1]]

  desc 'Build all'
  task :build => [:build_docker, :build_ubuntu] do

  end

  desc 'Build docker images'
  task :build_docker => :environment do
    sh('docker pull ubuntu:trusty')
    sh("docker build -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker tag -f #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Build ubuntu packages'
  task :build_ubuntu => :environment do
    rev = ENV['REV']
    raise ArgumentError.new('You must define REV') if rev.blank?

    sh('mkdir -p build')
    sh('rm -rf build/ubuntu/')
    sh('cp -ar packaging/ubuntu build/')
    sh("sed -i \"s/VERSION/#{VERSION}-#{rev}/g\" build/ubuntu/#{NAME}/DEBIAN/control")
    sh("sed -i \"s/VERSION/#{VERSION}-#{rev}/g\" build/ubuntu/kontena-weave/DEBIAN/control")

    sh("cd build/ubuntu && dpkg-deb -b #{NAME} . && dpkg-deb -b kontena-weave .")
  end

  desc 'Push all'
  task :push => [:push_docker, :push_ubuntu] do
  end

  desc 'Push docker images'
  task :push_docker => :environment do
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Push ubuntu packages'
  task :push_ubuntu => :build_ubuntu do
    bintray_user = ENV['BINTRAY_USER']
    bintray_key = ENV['BINTRAY_KEY']
    rev = ENV['REV']
    raise ArgumentError.new('You must define BINTRAY_USER') if bintray_user.blank?
    raise ArgumentError.new('You must define BINTRAY_KEY') if bintray_key.blank?
    raise ArgumentError.new('You must define REV') if rev.blank?
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("curl -T ./release/#{NAME}_#{VERSION}-#{rev}_all.deb -u#{bintray_user}:#{bintray_key} https://api.bintray.com/content/kontena/kontena/#{NAME}/#{VERSION}/#{NAME}-#{VERSION}-#{rev}_all.deb")
    sh("curl -T ./release/kontena-weave_#{VERSION}-#{rev}_all.deb -u#{bintray_user}:#{bintray_key} https://api.bintray.com/content/kontena/kontena/kontena-agent/#{VERSION}/kontena-weave-#{VERSION}-#{rev}_all.deb")
  end
end
