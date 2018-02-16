require 'json'

module ServiceHelper
  def service_events(service, type: nil, lines: 1000)
    k = run! "kontena service events --lines=#{lines} #{service}"

    lines = k.out.lines[1..-1]
    lines.map{|l|
      time, type, data = l.split(' ', 3)

      {time: time, type: type, data: data}
    }
  end
end
