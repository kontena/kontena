

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
    sh("docker rmi #{DOCKER_NAME}:#{VERSION} || true")
    sh("docker build --no-cache --pull -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker rmi #{DOCKER_NAME}:#{v} || true")
      sh("docker tag #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
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
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/DEBIAN/postinst")
    sh("sed -i \"s/VERSION/#{VERSION}/g\" build/ubuntu/#{NAME}/etc/init/kontena-agent.conf")

    Dir.chdir("build/ubuntu") do
      sh("dpkg-deb -b #{NAME} .")
    end
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
  task :push_ubuntu => :environment do
    repo = ENV['REPO'] || 'kontena'
    bintray_user = ENV['BINTRAY_USER']
    bintray_key = ENV['BINTRAY_KEY']
    rev = ENV['REV']
    raise ArgumentError.new('You must define BINTRAY_USER') if bintray_user.blank?
    raise ArgumentError.new('You must define BINTRAY_KEY') if bintray_key.blank?
    raise ArgumentError.new('You must define REV') if rev.blank?
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("curl -T ./release/#{NAME}_#{VERSION}-#{rev}_all.deb -u#{bintray_user}:#{bintray_key} 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/#{NAME}-#{VERSION}-#{rev}_all.deb;deb_distribution=trusty;deb_component=main;deb_architecture=amd64'")
  end
end
