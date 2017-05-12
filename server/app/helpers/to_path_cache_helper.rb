module ToPathCacheHelper
  def self.included(base)
    base.class_exec do
      field :to_path, String

      set_callback :before, :save do |doc|
        doc.to_path = doc.build_path
      end

      set_callback :after, :initialize do |doc|
        if doc.to_path.nil? && !doc.new_record?
          # update the to_path cache in db for existing records without the cached path
          doc.update_attribute :to_path, doc.build_path
        end
      end
    end
  end
end
