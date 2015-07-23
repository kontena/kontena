
class CollectionIndexerJob
  include Celluloid
  include Celluloid::Logger

  def perform
    info 'CollectionIndexerJob: removing undefined indexes'
    system 'rake db:mongoid:remove_undefined_indexes > /dev/null'
    info 'CollectionIndexerJob: removing undefined indexes finished'

    info 'CollectionIndexerJob: creating indexes'
    system 'rake db:mongoid:create_indexes > /dev/null'
    info 'CollectionIndexerJob: creating indexes finished'

    unless ContainerLog.collection.capped?
      info 'CollectionIndexerJob: converting container_logs to capped'
      ContainerLog.collection.session.command(
        convertToCapped: ContainerLog.collection.name,
        capped: true,
        size: 5.gigabytes
      )
      info 'CollectionIndexerJob: finished converting container_logs to capped'
    end

    unless ContainerStat.collection.capped?
      info 'CollectionIndexerJob: converting container_stats to capped'
      ContainerStat.collection.session.command(
        convertToCapped: ContainerStat.collection.name,
        capped: true,
        size: 1.gigabyte
      )
      info 'CollectionIndexerJob: finished converting container_stats to capped'
    end
  end
end
