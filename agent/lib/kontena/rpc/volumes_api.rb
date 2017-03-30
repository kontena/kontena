module Kontena
  module Rpc
    class VolumesApi

      def notify_update(reason)
        Celluloid::Notifications.publish('volume:update', reason)
        {}
      end
    end
  end
end
