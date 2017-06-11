class GridServiceHealthCheck
  include Mongoid::Document

  field :uri, type: String, default: '/'
  field :timeout, type: Integer, default: 10
  field :interval, type: Integer, default: 60
  field :initial_delay, type: Integer, default: 10
  field :protocol, type: String
  field :port, type: Integer

  embedded_in :grid_service

  def is_valid?
    return false if protocol.nil?
    return false if protocol.empty?
    return false if port.nil?
    true
  end

end
