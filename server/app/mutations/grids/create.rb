require 'httpclient'
require './app/helpers/random_name_helper'

module Grids
  class Create < Mutations::Command
    include RandomNameHelper

    required do
      model :user
      string :name, nils: true, min_length: 3
      integer :initial_size, default: 3, min: 1, max: 7
    end

    def execute
      self.name = generate_name if self.name.blank?
      grid = Grid.create(
        name: self.name,
        discovery_url: discovery_url(self.initial_size),
        initial_size: self.initial_size
      )
      if grid.errors.size > 0
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end
      user.grids << grid

      grid
    end

    ##
    # @return [String]
    def discovery_url(initial_size)
      HTTPClient.new.get_content("https://discovery.etcd.io/new?size=#{initial_size}")
    end
  end
end
