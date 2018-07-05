module Shell
  class Error < StandardError
    def initialize(cmd, code, output)
      @cmd = cmd
      @code = code
      @output = output
    end

    def message
      "command failed with code #{@code}: #{@cmd}\n#{@output}"
    end
  end

  # @param [String] cmd
  # @param [Hash] opts
  # @return [Kommando]
  def run(cmd, opts = {})
    opts[:output] = debug_kommando? unless opts.has_key?(:output)
    Kommando.run(cmd, opts)
  end

  # @param [String] cmd
  # @param [Hash] opts
  # @raise [Error]
  # @return [Kommando]
  def run!(cmd, **opts)
    run(cmd, **opts).tap do |k|
      raise Error.new(cmd, k.code, k.out) unless k.code.zero?
    end
  end

  # @param [String] cmd
  # @param [Hash] opts
  # @return [Kommando]
  def kommando(cmd, opts = {})
    opts[:output] = debug_kommando? unless opts.has_key?(:output)
    Kommando.new(cmd, opts)
  end

  def debug_kommando?
    ENV.has_key?('DEBUG_KOMMANDO')
  end

  def ctrl_c
    "\x03".freeze
  end

  def fixture_dir(dir)
    "./spec/fixtures/#{dir}/"
  end

  def with_fixture_dir(dir)
    Dir.chdir(fixture_dir(dir)) do
      yield
    end
  end

  def uncolorize(input)
    input.gsub(/\e\[.+?m/, '')
  end
end
