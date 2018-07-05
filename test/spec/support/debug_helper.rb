module DebugHelper
  def debug?
    ENV.has_key?('DEBUG_SPECS')
  end

  def debug(msg = nil, &block)
    msg = msg || yield

    puts msg if debug?
  end
end
