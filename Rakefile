
require 'colorize'
require 'dotenv'
Dotenv.load

VERSION = File.read('./VERSION').strip
UBUNTU_IMAGE = 'kontena-ubuntu-build'
UBUNTU_REPO = ENV['UBUNTU_REPO'] || 'kontena'
PKG_REV = ENV['PKG_REV'] || '1'

namespace :release do

  def headline(text)
    puts text.colorize(:yellow)
  end

  task :setup => [:bump_version] do
    %w(agent cli server).each do |dir|
      Dir.chdir(dir) do
        sh("bundle install")
      end
    end
  end

  task :bump_version do
    headline "Bumping version to #{VERSION}"
    %w(agent cli server).each do |dir|
      File.write("./#{dir}/VERSION", VERSION)
    end
  end

  task :setup_ubuntu do
    headline "Building Docker image for Ubuntu package builds ..."
    sh("docker build -t #{UBUNTU_IMAGE} -f Dockerfile.build_ubuntu .")
  end

  task :build => [
    :setup,
    :build_server,
    :build_agent
  ]

  task :build_server do
    headline "Starting to build kontena-server ..."
    Dir.chdir('server') do
      sh("bundle exec rake release:build_docker")
    end
  end

  task :build_agent do
    headline "Starting to build kontena-agent ..."
    Dir.chdir('agent') do
      sh("bundle exec rake release:build_docker")
    end
  end

  task :build_cli do
    headline "Starting to build kontena-cli ..."
    Dir.chdir('cli') do
      sh("rake release:build")
    end
  end

  task :package_ubuntu => [
    :setup, :setup_ubuntu, :package_ubuntu_server, :package_ubuntu_agent
  ]

  task :package_ubuntu_server do
    sh("docker run -it --rm -w /server -v #{Dir.pwd}/server:/server #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :package_ubuntu_agent do
    sh("docker run -it --rm -w /agent -v #{Dir.pwd}/agent:/agent #{UBUNTU_IMAGE} rake release:build_ubuntu REV=#{PKG_REV}")
  end

  task :push => [
    :build,
    :push_server,
    :push_agent
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
      sh("rake release:push")
    end
  end

  task :push_ubuntu => [
    :package_ubuntu,
    :push_ubuntu_server,
    :push_ubuntu_agent
  ]

  task :push_ubuntu_server do
    Dir.chdir('server') do
      sh("rake release:push_ubuntu REV=#{PKG_REV} REPO=#{UBUNTU_REPO}")
    end
  end

  task :push_ubuntu_agent do
    Dir.chdir('agent') do
      sh("rake release:push_ubuntu REV=#{PKG_REV} REPO=#{UBUNTU_REPO}")
    end
  end
end
