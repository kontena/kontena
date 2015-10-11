class MigrateOverlayCidr < Mongodb::Migration

  def self.up
    Container.unscoped.where(overlay_cidr: {"$exists" => 1}).each do |c|
      data = c.raw_attributes
      if data['overlay_cidr'].include?('/')
        ip, subnet = data['overlay_cidr'].split('/')
        begin
          OverlayCidr.create(
            grid: c.grid,
            container: c,
            ip: ip,
            subnet: subnet
          )
        rescue Moped::Errors::OperationFailure
        end
      end
      c.unset(:overlay_cidr)
    end
  end
end
