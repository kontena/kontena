namespace :release do

  VERSION = Gem::Version.new(File.read('../VERSION').strip)
  DOCKER_NAME = 'kontena/docs'
  if VERSION.prerelease?
    DOCKER_VERSIONS = ['edge']
  else
    DOCKER_VERSIONS = ['latest', VERSION.to_s.match(/(\d+\.\d+)/)[1]]
  end

  desc "Build docs image"
  task :build do
    sh("which gitbook || npm install -g gitbook-cli")
    sh("gitbook install && gitbook build")
    tags = DOCKER_VERSIONS.map { |v| "-t #{DOCKER_NAME}:#{v}"}
    sh("docker build #{tags.join(' ')} .")
  end

  desc "Push docs image"
  task :push => :build do
    DOCKER_VERSIONS.each do |v|
      sh("docker push #{DOCKER_NAME}:#{v}")
    end
  end
end
