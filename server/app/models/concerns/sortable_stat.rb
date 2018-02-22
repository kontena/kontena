module SortableStat
  extend ActiveSupport::Concern

  module ClassMethods
    def latest
      asc(:id).last
    end
  end
end