namespace :release do
  VERSION = Gem::Version.new(File.read('VERSION').strip)
  NAME = 'kontena-server'
  DOCKER_NAME = 'kontena/server'
  if VERSION.prerelease?
    DOCKER_VERSIONS = ['edge']
    DEB_COMPONENT = 'edge'
  else
    DOCKER_VERSIONS = ['latest', VERSION.to_s.match(/(\d+\.\d+)/)[1]]
    DEB_COMPONENT = 'main'
  end

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
    Dir.chdir("build/ubuntu") do
      sh("dpkg-deb -b #{NAME} .")
    end
    sh('rm -rf release/trusty && mkdir -p release/trusty')
    sh('cp build/ubuntu/*.deb release/trusty')
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
    Dir.chdir("build/ubuntu_xenial") do
      sh("dpkg-deb -b #{NAME} .")
    end
    sh('rm -rf release/xenial && mkdir -p release/xenial')
    sh('cp build/ubuntu_xenial/*.deb release/xenial')
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
    sh("curl --netrc -T ./release/trusty/#{NAME}_#{VERSION}-#{rev}_all.deb 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/pool/#{DEB_COMPONENT}/k/#{NAME}-#{VERSION}-#{rev}~trusty_all.deb;deb_distribution=trusty;deb_component=#{DEB_COMPONENT};deb_architecture=amd64;publish=1'")
    sh("curl --netrc -T ./release/xenial/#{NAME}_#{VERSION}-#{rev}_all.deb 'https://api.bintray.com/content/kontena/#{repo}/#{NAME}/#{VERSION}/pool/#{DEB_COMPONENT}/k/#{NAME}-#{VERSION}-#{rev}~xenial_all.deb;deb_distribution=xenial;deb_component=#{DEB_COMPONENT};deb_architecture=amd64;publish=1'")
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
