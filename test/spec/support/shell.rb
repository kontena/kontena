module Shell

  def run(cmd, opts = {})
    Kommando.run(cmd, opts)
  end

  def kommando(cmd, opts = {})
    Kommando.new(cmd, opts)
  end

  def ctrl_c
    "\x03".freeze
  end

  def with_fixture_dir(dir)
    Dir.chdir("./spec/fixtures/#{dir}/") do
      yield
    end
  end
end
