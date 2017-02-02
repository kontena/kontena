module Setup

  def skip_setup?
    ENV['SKIP_SETUP'] == 'true'
  end

  def set_home
    ENV['HOME'] = '/tmp'
  end

  def setup_master(version)
    File.delete("#{Dir.home}/.kontena_client.json") if File.exist?("#{Dir.home}/.kontena_client.json")
    k = Kommando.new "kontena vagrant master create --skip-auth-provider --name e2e --version #{version}", output: true
    expect(k.run).to be_truthy
  end

  def teardown_master
    Kommando.run "kontena vagrant master terminate --force", output: true
  end

  def setup_grid(name, initial_size = 1, version = nil)
    Kommando.run "kontena grid create --initial-size #{initial_size} #{name}", output: true
    3.times do |i|
      Kommando.run("kontena vagrant node create --version #{version} #{name}-#{i + 1}", output: true)
    end
  end

  def teardown_grid(name, size)
    size.times do |i|
      Kommando.run "kontena vagrant node terminate --force node-#{i + 1}", output: true
    end
  end
end
