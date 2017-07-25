require 'logger'

module Kontena::Logging
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

  # Prefix for log messages, defaults to class name
  #
  # @return [String]
  def logging_prefix
    self.class.name
  end

  # Send a debug message
  # @param message [String]
  def debug(message = nil, &block)
    logger.add(Logger::DEBUG, message, logging_prefix, &block)
  end

  # Send a info message
  # @param message [String]
  def info(message = nil, &block)
    logger.add(Logger::INFO, message, logging_prefix, &block)
  end

  # Send a warning message
  # @param message [String]
  def warn(message = nil, &block)
    logger.add(Logger::WARN, message, logging_prefix, &block)
  end

  # Send an error message
  # @param message [String]
  def error(message = nil, &block)
    logger.add(Logger::ERROR, message, logging_prefix, &block)
  end
end
