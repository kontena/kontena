require 'logger'

module Kontena
  module Logging

    def self.initialize_logger(log_target = STDOUT, log_level = Logger::INFO)
      @logger = Logger.new(log_target)
      @logger.level = log_level
      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : initialize_logger
    end

    def self.logger=(log)
      @logger = (log ? log : Logger.new('/dev/null'))
    end

    # @return [Logger]
    def logger
      Kontena::Logging.logger
    end

    # Send a debug message
    # @param [String] string
    # @yield optionally set the message using a block
    def debug(string = nil, &block)
      if block_given?
        logger.debug(self.class.name, &block)
      else
        logger.debug(self.class.name) { string }
      end
    end

    # Send a info message
    # @param [String] string
    # @yield optionally set the message using a block
    def info(string = nil, &block)
      if block_given?
        logger.debug(self.class.name, &block)
      else
        logger.info(self.class.name) { string }
      end
    end

    # Send a warning message
    # @param [String] string
    # @yield optionally set the message using a block
    def warn(string = nil, &block)
      if block_given?
        logger.warn(self.class.name, &block)
      else
        logger.warn(self.class.name) { string }
      end
    end

    # Send an error message
    # @param [String] string
    # @yield optionally set the message using a block
    def error(string = nil, &block)
      if block_given?
        logger.error(self.class.name, &block)
      else
        logger.error(self.class.name) { string }
      end
    end
  end
end
