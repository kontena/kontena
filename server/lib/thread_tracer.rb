class ThreadTracer
  @debug = ENV['THREAD_DEBUG']
  @fatal = false

  def self.caller(skip = 1)
    Caller.new(skip + 1)
  end

  # Calling process/thread, with stack trace
  class Caller
    def initialize(skip = 1)
      @process = Process.pid
      @thread = Thread.current
      @stack = Kernel.caller(skip + 1)
    end

    # Is this being called from the owning thread?
    def same_thread?
      @process == Process.pid && @thread == Thread.current
    end

    def to_s
      "process=#{@process} thread=#{@thread}:\n#{@stack.map{|x|"\t#{x}"}.join("\n")}"
    end
  end

  # Abort on errors
  # Intended for test and development
  def self.fatal!
    @fatal = true
  end
  
  def self.fatal?
    @fatal
  end

  def self.debug?
    @debug
  end

  # Output optional debugging-level information from block
  def self.debug(&block)
    $stderr.puts(yield) if debug?
  end

  # Output or abort
  def self.error(msg)
    if fatal?
      abort msg
    else
      $stderr.puts(msg)
    end
  end

  # @param [String] description of traced object
  def initialize(subject, skip: 1)
    @subject = subject
    @owner = ThreadTracer.caller(skip + 1)

    ThreadTracer.debug { "TRACE #{@subject} @ #{@owner}"}
  end

  # Error unless called from owning thread
  def check!
    unless @owner.same_thread?
      ThreadTracer.error "THREAD CONFLICT ON #{@subject} @ #{ThreadTracer.caller}\nOWNING THREAD #{@owner}"
    end
  end
end
