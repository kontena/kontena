module AsyncHelper
  include Logging

  # Run block in a new thread. Log exceptions.
  #
  # @yield
  # @return [Thread] don't care about it
  def async_thread(&block)
    Thread.new {
      begin
        yield
      rescue Exception => exc
        error exc
      end
    }
  end
end
