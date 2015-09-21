
require 'colorize'
require 'dotenv'
Dotenv.load

VERSION = File.read('./VERSION').strip
UBUNTU_IMAGE = 'kontena-ubuntu-build'
PKG_REV = ENV['PKG_REV'] || '1'

namespace :release do

  def headline(text)
    puts text.colorize(:yellow)
  end

  task :setup do
    headline "Bumping version to #{VERSION}"
    %w(agent cli server).each do |dir|
      File.write("./#{dir}/VERSION", VERSION)
    end
    headline "Building Docker image for Ubuntu package builds ..."
    sh("docker build -t #{UBUNTU_IMAGE} -f Dockerfile.build_ubuntu .")
  end

  task :build => [
    :setup,
    :build_server,
    :build_agent,
    :build_cli
  ]

  task :build_server do
    headline "Starting to build kontena-server ..."
    Dir.chdir('server') do
      sh("rake release:build_docker")
    end
  end

  task :build_agent do
    headline "Starting to build kontena-agent ..."
    Dir.chdir('agent') do
      sh("rake release:build_docker")
    end
  end

  task :build_cli do
    headline "Starting to build kontena-cli ..."
    Dir.chdir('cli') do
      sh("gem build kontena-cli.gemspec")
    end
  end

  task :package_ubuntu => [
    :setup, :package_ubuntu_server, :package_ubuntu_agent
  ]

  task :package_ubuntu_server do
    sh("docker run -it --rm -w /build/server -v #{Dir.pwd}/server/build:/build/server/build #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :package_ubuntu_agent do
    sh("docker run -it --rm -w /build/agent -v #{Dir.pwd}/agent/build:/build/agent/build #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :push => [
    :build,
    :push_server,
    :push_agent,
    :push_cli
  ]

  task :push_server do
    headline "Starting to push kontena/server ..."
    Dir.chdir('server') do
      sh("rake release:push_docker")
    end
  end

  task :push_agent do
    headline "Starting to push kontena/agent ..."
    Dir.chdir('agent') do
      sh("rake release:push_docker")
    end
  end

  task :push_cli do
    headline "Starting to push kontena-cli ..."
    Dir.chdir('cli') do
      sh("gem push kontena-cli-#{VERSION}.gem")
    end
  end

  task :push_ubuntu => [:build_ubuntu] do
    Dir.chdir('server') do
      sh("rake release:push_ubuntu REV=#{PKG_REV}")
    end
    Dir.chdir('agent') do
      sh("rake release:push_ubuntu REV=#{PKG_REV}")
    end
  end
end
