require 'securerandom'
require_relative '../models/configuration'

Configuration.create_indexes
Configuration.seed('config/seed.yml')
