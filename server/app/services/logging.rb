require 'logger'

module Logging

  def self.initialize_logger(log_target = STDOUT)
    @logger = Logger.new(log_target)
    @logger.level = Logger::INFO
    @logger
  end

  def self.logger
    defined?(@logger) ? @logger : initialize_logger
  end

  def self.logger=(log)
    @logger = (log ? log : Logger.new('/dev/null'))
  end

  def logger
    Logging.logger
  end

  # Send a debug message
  # @param [String] string
  def debug(string)
    logger.debug(self.class.name) { string }
  end

  # Send a info message
  # @param [String] string
  def info(string)
    logger.info(self.class.name) { string }
  end

  # Send a warning message
  # @param [String] string
  def warn(string)
    logger.warn(self.class.name) { string }
  end

  # Send an error message
  # @param [String] string
  def error(string)
    logger.error(self.class.name) { string }
  end
end
