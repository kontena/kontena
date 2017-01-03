namespace :release do
  VERSION = Gem::Version.new(File.read('VERSION').strip)
  NAME = 'kontena-server'
  DOCKER_NAME = 'kontena/server'
  if VERSION.prerelease?
    DOCKER_VERSIONS = ['edge']
  else
    DOCKER_VERSIONS = ['latest', VERSION.to_s.match(/(\d+\.\d+)/)[1]]
  end
  BINTRAY_USER = ENV['BINTRAY_USER']
  BINTRAY_KEY = ENV['BINTRAY_KEY']

  desc 'Build Ubuntu packages'
  task :build_ubuntu => [:build_ubuntu_trusty, :build_ubuntu_xenial] do
  end

  desc 'Build ubuntu trusty package'
  task :build_ubuntu_trusty do
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

  desc 'Build ubuntu xenial package'
  task :build_ubuntu_xenial do
    rev = ENV['REV'] || 1
    raise ArgumentError.new('You must define REV') if rev.blank?

    sh('mkdir -p build')
    sh('rm -rf build/ubuntu_xenial/')
    sh('cp -ar packaging/ubuntu_xenial build/')
    sh("sed -i \"s/VERSION/#{VERSION}-#{rev}/g\" build/ubuntu_xenial/#{NAME}/DEBIAN/control")
    sh("sed -i \"s/{{VERSION}}/#{VERSION}/g\" build/ubuntu_xenial/#{NAME}/lib/systemd/system/kontena-server.service.d/kontena-version.conf")
    sh("cd build/ubuntu_xenial && dpkg-deb -b #{NAME} .")
  end

  desc 'Build docker image'
  task :build_docker do
    sh("docker rmi #{DOCKER_NAME}:#{VERSION} || true")
    sh("docker build --no-cache --pull -t #{DOCKER_NAME}:#{VERSION} .")
    DOCKER_VERSIONS.each do |v|
      sh("docker rmi #{DOCKER_NAME}:#{v} || true")
      sh("docker tag #{DOCKER_NAME}:#{VERSION} #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Build all'
  task :build => [:build_ubuntu, :build_ubuntu_xenial, :build_docker] do
  end

  desc 'Upload ubuntu packages'
  task :push_ubuntu do
    rev = ENV['REV'] || '1'
    repo = ENV['REPO'] || 'ubuntu'
    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu/*.deb release/')
    sh("curl -T ./release/#{NAME}_#{VERSION}-#{rev}_all.deb -u#{BINTRAY_USER}:#{BINTRAY_KEY} 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/pool/main/k/#{NAME}-#{VERSION}-#{rev}~trusty_all.deb;deb_distribution=trusty;deb_component=main;deb_architecture=amd64'")

    sh('rm -rf release && mkdir release')
    sh('cp build/ubuntu_xenial/*.deb release/')
    sh("curl -T ./release/#{NAME}_#{VERSION}-#{rev}_all.deb -u#{BINTRAY_USER}:#{BINTRAY_KEY} 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/pool/main/k/#{NAME}-#{VERSION}-#{rev}~xenial_all.deb;deb_distribution=xenial;deb_component=main;deb_architecture=amd64'")
  end

  desc 'Upload docker image'
  task :push_docker do
    sh("docker push #{DOCKER_NAME}:#{VERSION}")
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
  end

  desc 'Build docs image'
  task :build_docs do
    Bundler.with_clean_env do
      Dir.chdir('docs') do
        sh("bundle install")
        sh("bundle exec middleman build")
        sh("docker rmi kontena/master-api-docs:#{VERSION} || true")
        sh("docker build --no-cache --pull -t kontena/master-api-docs:#{VERSION} .")
      end
    end
  end

  desc 'Push docs image'
  task :push_docs do
    Dir.chdir('docs') do
      sh("docker push kontena/master-api-docs:#{VERSION}")
    end
  end
end
