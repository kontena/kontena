module Workers

  # @param [String, Symbol] name
  def worker(name)
    worker = "#{name}_worker"
    Celluloid::Actor[worker.to_sym]
  end
end