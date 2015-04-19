require 'docker'
require 'faye/websocket'
require 'eventmachine'
require 'thread'
require 'celluloid'
require 'active_support/core_ext/time'
require 'active_support/core_ext/module/delegation'

Celluloid.logger.level = Logger::ERROR

require_relative 'kontena/container_info_worker'
require_relative 'kontena/event_worker'
require_relative 'kontena/log_worker'
require_relative 'kontena/queue_worker'
require_relative 'kontena/stats_worker'
require_relative 'kontena/websocket_client'
require_relative 'kontena/dns_server'

