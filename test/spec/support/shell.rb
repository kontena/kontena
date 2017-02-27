module Shell

  # @param [String] cmd
  # @param [Hash] opts
  # @return [Kommando]
  def run(cmd, opts = {})
    opts[:output] = debug? unless opts.has_key?(:output)
    Kommando.run(cmd, opts)
  end

  # @param [String] cmd
  # @param [Hash] opts
  # @return [Kommando]
  def kommando(cmd, opts = {})
    opts[:output] = debug? unless opts.has_key?(:output)
    Kommando.new(cmd, opts)
  end

  def debug?
    ENV.has_key?('DEBUG_KOMMANDO')
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
