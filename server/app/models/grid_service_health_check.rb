class GridServiceHealthCheck
  include Mongoid::Document

  field :uri, type: String, default: '/'
  field :timeout, type: Fixnum, default: 10
  field :interval, type: Fixnum, default: 60
  field :initial_delay, type: Fixnum, default: 10
  field :protocol, type: String
  field :port, type: Fixnum

  embedded_in :grid_service

  def is_valid?
    return false if protocol.nil?
    return false if protocol.empty?
    return false if port.nil?
    true
  end

end
