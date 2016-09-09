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
end
