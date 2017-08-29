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

    # @return [String]
    def logging_prefix
      self.class.name
    end

    # Send a debug message
    # @param message [String]
    # @yield optionally set the message using a block
    def debug(message = nil, &block)
      logger.add(Logger::DEBUG, message, self.logging_prefix, &block)
    end

    # Send a info message
    # @param message [String]
    # @yield optionally set the message using a block
    def info(message = nil, &block)
      logger.add(Logger::INFO, message, self.logging_prefix, &block)
    end

    # Send a warning message
    # @param message [String]
    # @yield optionally set the message using a block
    def warn(message = nil, &block)
      logger.add(Logger::WARN, message, self.logging_prefix, &block)
    end

    # Send an error message
    # @param message [String]
    # @yield optionally set the message using a block
    def error(message = nil, &block)
      logger.add(Logger::ERROR, message, self.logging_prefix, &block)
    end
  end
end
