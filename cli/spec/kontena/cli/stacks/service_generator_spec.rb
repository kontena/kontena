require "kontena/cli/stacks/service_generator"

describe Kontena::Cli::Stacks::ServiceGenerator do
  let(:subject) do
    described_class.new({})
  end

  describe '#parse_data' do
    context 'volumes' do
      it 'returns volumes if set' do
        data = {
          'image' => 'foo/bar:latest',
          'volumes' => [
            'mongodb-1'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['volumes']).to eq(data['volumes'])
      end

      it 'returns empty volumes if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['volumes']).to eq([])
      end
    end

    context 'volumes_from' do
      it 'returns volumes_from if set' do
        data = {
          'image' => 'foo/bar:latest',
          'volumes_from' => [
            'mongodb-1'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['volumes_from']).to eq(data['volumes_from'])
      end

      it 'returns empty volumes_from if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['volumes_from']).to eq([])
      end
    end

    context 'command' do
      it 'returns cmd array if set' do
        data = {
          'image' => 'foo/bar:latest',
          'command' => 'ls -la'
        }
        result = subject.send(:parse_data, data)
        expect(result['cmd']).to eq(data['command'].split(' '))
      end

      it 'does not return cmd if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?('cmd')).to be_falsey
      end
    end

    context 'affinity' do
      it 'returns affinity if set' do
        data = {
          'image' => 'foo/bar:latest',
          'affinity' => [
            'label==az=b'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['affinity']).to eq(data['affinity'])
      end

      it 'returns affinity as empty array if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?('affinity')).to be_truthy
        expect(result['affinity']).to eq([])
      end
    end

    context 'user' do
      it 'returns user if set' do
        data = {
          'image' => 'foo/bar:latest',
          'user' => 'user'
        }
        result = subject.send(:parse_data, data)
        expect(result['user']).to eq('user')
      end

      it 'does not return user if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?('user')).to be_falsey
      end
    end

    context 'stateful' do
      it 'returns stateful if set' do
        data = {
          'image' => 'foo/bar:latest',
          'stateful' => true
        }
        result = subject.send(:parse_data, data)
        expect(result['stateful']).to eq(true)
      end

      it 'returns stateful as false if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['stateful']).to eq(false)
      end
    end

    context 'links' do
      it 'returns empty array if links not set' do
        data = {
          'image' => 'wordpress:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['links']).to eq([])
      end

      it 'returns parsed links array' do
        data = {
          'image' => 'wordpress:latest',
          'links' => ['mysql:db']
        }
        result = subject.send(:parse_data, data)
        expect(result['links']).to eq([{
          'name' => 'mysql',
          'alias' => 'db'
        }])
      end
    end
    context 'privileged' do
      it 'returns privileged if set' do
        data = {
          'image' => 'foo/bar:latest',
          'privileged' => false
        }
        result = subject.send(:parse_data, data)
        expect(result['privileged']).to eq(false)
      end

      it 'does not return privileged if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['privileged']).to be_nil
      end
    end

    context 'cap_add' do
      it 'returns cap_drop if set' do
        data = {
          'image' => 'foo/bar:latest',
          'cap_add' => [
            'NET_ADMIN'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['cap_add']).to eq(data['cap_add'])
      end

      it 'does not return cap_add if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['cap_add']).to be_nil
      end
    end

    context 'cap_drop' do
      it 'returns cap_drop if set' do
        data = {
          'image' => 'foo/bar:latest',
          'cap_drop' => [
            'NET_ADMIN'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['cap_drop']).to eq(data['cap_drop'])
      end

      it 'does not return cap_drop if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['cap_drop']).to be_nil
      end
    end

    context 'net' do
      it 'returns net if set' do
        data = {
          'image' => 'foo/bar:latest',
          'net' => 'host'
        }
        result = subject.send(:parse_data, data)
        expect(result['net']).to eq('host')
      end

      it 'does not return pid if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['net']).to be_nil
      end
    end

    context 'pid' do
      it 'returns pid if set' do
        data = {
          'image' => 'foo/bar:latest',
          'pid' => 'host'
        }
        result = subject.send(:parse_data, data)
        expect(result['pid']).to eq('host')
      end

      it 'does not return pid if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['pid']).to be_nil
      end
    end

    context 'log_driver' do
      it 'returns log_driver if set' do
        data = {
          'image' => 'foo/bar:latest',
          'log_driver' => 'syslog'
        }
        result = subject.send(:parse_data, data)
        expect(result['log_driver']).to eq('syslog')
      end

      it 'does not return log_driver if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['log_driver']).to be_nil
      end
    end

    context 'log_opt' do
      it 'returns log_opts hash if log_opt is set' do
        data = {
          'image' => 'foo/bar:latest',
          'log_driver' => 'fluentd',
          'log_opt' => {
            'fluentd-address' => '192.168.99.1:24224',
            'fluentd-tag' => 'docker.{{.Name}}'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['log_opts']).to eq(data['log_opt'])
      end

      it 'does not return log_opts if log_opt is not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['log_opts']).to be_nil
      end
    end

    context 'deploy_opts' do
      it 'returns deploy_opts if deploy.wait_for_port is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'wait_for_port' => '8080'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['deploy_opts']['wait_for_port']).to eq('8080')
      end

      it 'returns deploy_opts if deploy.min_health is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'min_health' => '0.5'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['deploy_opts']['min_health']).to eq('0.5')
      end

      it 'sets strategy if deploy.strategy is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'strategy' => 'daemon'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['strategy']).to eq('daemon')
      end

      it 'sets interval if deploy.interval is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'interval' => '1min'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['deploy_opts']['interval']).to eq(60)
      end

      it 'returns nil values if no deploy options are defined' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result['deploy_opts']).to eq({
          'interval' => nil,
          'min_health' => nil,
          'wait_for_port' => nil
          })
      end
    end

    context 'hooks' do
      it 'returns hooks hash if defined' do
        data = {
          'image' => 'foo/bar:latest',
          'hooks' => {
            'post_start' => []
          }
        }
        result = subject.send(:parse_data, data)
        expect(result['hooks']).to eq(data['hooks'])
      end

      it 'does returns empty hook hash if not defined' do
        data = {'image' => 'foo/bar:latest'}
        result = subject.send(:parse_data, data)
        expect(result['hooks']).to eq({})
      end
    end

    context 'secrets' do
      it 'returns secrets array if defined' do
        data = {
          'image' => 'foo/bar:latest',
          'secrets' => [
            {'secret' => 'MYSQL_ADMIN_PASSWORD', 'name' =>  'WORDPRESS_DB_PASSWORD', 'type' => 'env'}
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result['secrets']).to eq(data['secrets'])
      end

      it 'does not return secrets if not defined' do
        data = {'image' => 'foo/bar:latest'}
        result = subject.send(:parse_data, data)
        expect(result['secrets']).to be_nil
      end
    end

    context 'health_check' do
      it 'returns health_check with nils by default' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        health_check = result['health_check']
        expect(health_check['port']).to be_nil
        expect(health_check['protocol']).to be_nil
      end

      it 'returns health_check with port & protocol' do
        data = {
          'image' => 'foo/bar:latest',
          'health_check' => {
            'port' => 8080,
            'protocol' => 'tcp'
          }
        }
        result = subject.send(:parse_data, data)
        health_check = result['health_check']
        expect(health_check['port']).to eq(8080)
        expect(health_check['protocol']).to eq('tcp')
        expect(health_check['uri']).to be_nil
      end

      it 'returns health_check with all values' do
        data = {
          'image' => 'foo/bar:latest',
          'health_check' => {
            'port' => 8080,
            'protocol' => 'http',
            'uri' => '/health',
            'interval' => 60,
            'timeout' => 5,
            'initial_delay' => 30
          }
        }
        result = subject.send(:parse_data, data)
        health_check = result['health_check']
        expect(health_check['port']).to eq(8080)
        expect(health_check['protocol']).to eq('http')
        expect(health_check['uri']).to eq('/health')
        expect(health_check['interval']).to eq(60)
        expect(health_check['timeout']).to eq(5)
        expect(health_check['initial_delay']).to eq(30)
      end
    end
  end
end
