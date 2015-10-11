class SchemaMigration
  include Mongoid::Document

  field :version, type: Integer
end
