require 'securerandom'
require_relative '../models/configuration'
require_relative 'mongoid'


Configuration.seed('config/seed.yml')
