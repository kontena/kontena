namespace :release do
  VERSION = File.read('VERSION').strip
  DOCKER_NAME = 'kontena/cli'
  DOCKER_VERSIONS = ['latest', VERSION.match(/(\d+\.\d+)/)[1]]

  desc 'Build all'
  task :build => [:build_docker] do
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
end
