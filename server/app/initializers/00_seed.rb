require 'securerandom'
require_relative '../models/configuration'
require_relative 'mongoid'

Configuration.create_indexes
Configuration.seed('config/seed.yml')
