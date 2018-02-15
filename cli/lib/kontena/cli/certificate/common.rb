module Kontena::Cli::Certificate
  module Common
    def show_certificate(cert)
      puts "#{cert['id']}:"
      puts "  subject: #{cert['subject']}"
      puts "  valid until: #{Time.parse(cert['valid_until']).utc.strftime("%FT%TZ")}"
      if cert['alt_names'] && !cert['alt_names'].empty?
        puts "  alt names:"
        cert['alt_names'].each do |alt_name|
          puts "    - #{alt_name}"
        end
      end
      puts "  auto renewable: #{cert['auto_renewable']}"
    end
  end
end
