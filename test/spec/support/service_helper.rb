require 'json'

module ServiceHelper
  def service_events(service, lines: 1000)
    k = run! "kontena service events --lines=#{lines} #{service}"

    lines = k.out.lines[1..-1]
    lines.map{|l|
      time, type, data = l.split(' ', 3)

      {time: time, type: type, data: data}
    }
  end

  def service_logs(service, lines: 1000)
    k = run! "kontena service logs --lines=#{lines} #{service}"

    k.out.lines
  end
end
