module Kontena
  module Callbacks
    class InstallSslCertificateAfterDeploy < Kontena::Callback

      matches_commands 'master create'

      def after
        extend Kontena::Cli::Common

        return unless command.exit_code == 0
        return unless command.result.kind_of?(Hash)
        return unless command.result.has_key?(:ssl_certificate)
        return unless command.result.has_key?(:public_ip)

        cert_dir = File.join(Dir.home, '.kontena/certs')
        unless File.directory?(cert_dir)
          require 'fileutils'
          FileUtils.mkdir_p(cert_dir)
        end

        cert_file = File.join(cert_dir, "#{command.result[:public_ip]}.pem")

        spinner "Installing SSL certificate to #{cert_file}" do
          File.unlink(cert_file) if File.exist?(cert_file)
          File.write(cert_file, command.result[:ssl_certificate])
        end
      end
    end
  end
end


