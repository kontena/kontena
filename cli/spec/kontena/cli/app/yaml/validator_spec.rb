require 'kontena/cli/apps/yaml/validator'

describe Kontena::Cli::Apps::YAML::Validator do

  describe '#validate_options' do
    context 'build' do
      it 'is optional' do
        result = subject.validate_options({})
        expect(result.valid?).to be_truthy

        expect(result.errors.key?('build')).to be_falsey
      end

      it 'must be string' do
        result = subject.validate_options('build' => 12345)
        expect(result.errors.key?('build')).to be_truthy

        result = subject.validate_options('build' => '.')
        expect(result.errors.key?('build')).to be_falsey
      end
    end

    context 'image' do
      it 'is optional' do
        result = subject.validate_options('build' => '.')
        expect(result.valid?).to be_truthy
        expect(result.errors.key?('image')).to be_falsey
      end

      it 'must be string' do
        result = subject.validate_options('image' => 10)
        expect(result.valid?).to be_falsey
        expect(result.errors.key?('image')).to be_truthy
      end
    end

    it 'validates stateful is boolean' do
      result = subject.validate_options('stateful' => 'bool')
      expect(result.errors.key?('stateful')).to be_truthy
    end

    it 'validates net is host or bridge' do
      result = subject.validate_options('net' => 'invalid')
      expect(result.errors.key?('net')).to be_truthy

      result = subject.validate_options('net' => 'bridge')
      expect(result.errors.key?('net')).to be_falsey

      result = subject.validate_options('net' => 'host')
      expect(result.errors.key?('net')).to be_falsey
    end

    context 'affinity' do
      it 'is optional' do
        result = subject.validate_options({})
        expect(result.errors.key?('affinity')).to be_falsey
      end

      it 'must be array' do
        result = subject.validate_options('affinity' => 'node==node1')
        expect(result.errors.key?('affinity')).to be_truthy
        result = subject.validate_options('affinity' => ['node==node1'])
        expect(result.errors.key?('affinity')).to be_falsey
      end

      it 'validates format' do
        result = subject.validate_options('affinity' => ['node=node1'])
        expect(result.errors.key?('affinity')).to be_truthy

        result = subject.validate_options('affinity' => ['node==node1', 'service!=mariadb'])
        expect(result.errors.key?('affinity')).to be_falsey
      end
    end

    context 'deploy' do
      it 'is optional' do
        result = subject.validate_options({})
        expect(result.errors.key?('deploy')).to be_falsey
      end

      context 'strategy' do
        it 'accepts daemon' do
          result = subject.validate_options('deploy' => {'strategy' => 'daemon'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'accepts random' do
          result = subject.validate_options('deploy' => {'strategy' => 'random'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'accepts ha' do
          result = subject.validate_options('deploy' => {'strategy' => 'ha'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'rejects invalid values' do
          result = subject.validate_options('deploy' => {'strategy' => 'global'})
          expect(result.errors.key?('deploy')).to be_truthy
        end
      end

      context 'interval' do
        it 'rejects wrong format' do
          result = subject.validate_options('deploy' => {'interval' => '1xyz'})
          expect(result.errors.key?('deploy')).to be_truthy
        end

        it 'accepts 1min as value' do
          result = subject.validate_options('deploy' => {'interval' => '1min'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'accepts 1h as value' do
          result = subject.validate_options('deploy' => {'interval' => '1h'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'accepts 1d as value' do
          result = subject.validate_options('deploy' => {'interval' => '1d'})
          expect(result.errors.key?('deploy')).to be_falsey
        end

        it 'accepts integer as value' do
          result = subject.validate_options('deploy' => {'interval' => '100'})
          expect(result.errors.key?('deploy')).to be_falsey
        end
      end
    end

    context 'command' do
      it 'is optional' do
        result = subject.validate_options({})
        expect(result.errors.key?('command')).to be_falsey
      end

      it 'must be string or empty' do
        result = subject.validate_options('command' => 1234)
        expect(result.errors.key?('command')).to be_truthy

        result = subject.validate_options('command' => nil)
        expect(result.errors.key?('command')).to be_falsey

        result = subject.validate_options('command' => 'bundle exec rails s')
        expect(result.errors.key?('command')).to be_falsey
      end
    end

    it 'validates cpu_shares is integer' do
      result = subject.validate_options('cpu_shares' => '1m')
      expect(result.errors.key?('cpu_shares')).to be_truthy
      result = subject.validate_options('cpu_shares' => 1024)
      expect(result.errors.key?('cpu_shares')).to be_falsey
      result = subject.validate_options({})
      expect(result.errors.key?('cpu_shares')).to be_falsey
    end

    it 'validates environment is array or hash' do
      result = subject.validate_options('environment' => 'KEY=VALUE')
      expect(result.errors.key?('environment')).to be_truthy
      result = subject.validate_options('environment' => ['KEY=VALUE'])
      expect(result.errors.key?('environment')).to be_falsey
      result = subject.validate_options('environment' => { 'KEY' => 'VALUE' })
      expect(result.errors.key?('environment')).to be_falsey
    end

    context 'validates secrets' do
      it 'must be array' do
        result = subject.validate_options('secrets' => {})
        expect(result.errors.key?('secrets')).to be_truthy
      end

      context 'item' do
        it 'must contain secret' do
          result = subject.validate_options('secrets' => [{ 'name' => 'test', 'type' => 'env' }])
          expect(result.errors.key?('secrets')).to be_truthy
        end

        it 'must contain name' do
          result = subject.validate_options('secrets' => [{ 'secret' => 'test', 'type' => 'env' }])
          expect(result.errors.key?('secrets')).to be_truthy
        end

        it 'must contain type' do
          result = subject.validate_options('secrets' => [{ 'secret' => 'test', 'name' => 'test' }])
          expect(result.errors.key?('secrets')).to be_truthy
        end

        it 'accepts valid input' do
          result = subject.validate_options('secrets' =>
            [
              {
                'secret' => 'test',
                'name' => 'test',
                'type' => 'env'
              }
            ])
          expect(result.errors.key?('secrets')).to be_falsey
        end
      end
    end

    context 'validates extends' do
      it 'accepts string value' do
        result = subject.validate_options('extends' => 'web')
        expect(result.errors.key?('extends')).to be_falsey
      end

      context 'when value is hash' do
        it 'must contain service' do
          result = subject.validate_options('extends' => { 'file' => 'docker_compose.yml'})
          expect(result.errors.key?('extends')).to be_truthy
        end
      end

      context 'when value is not string or hash' do
        it 'returns error' do
          result = subject.validate_options('extends' => ['array is invalid'])
          expect(result.errors.key?('extends')).to be_truthy
        end
      end
    end
    context 'validates hooks' do
      context 'validates pre_build' do
        it 'must be array' do
          result = subject.validate_options('hooks' => { 'pre_build' => {} })
          expect(result.errors.key?('hooks')).to be_truthy
          data = {
            'hooks' => {
              'pre_build' => [
                {
                  'cmd' => 'rake db:migrate'
                }
              ]
            }
          }
          result = subject.validate_options(data)
          expect(result.errors.key?('hooks')).to be_falsey
        end
      end
      context 'validates post_start' do
        it 'must be array' do
          result = subject.validate_options('hooks' => { 'post_start' => {} })
          expect(result.errors.key?('hooks')).to be_truthy
          data = {
            'hooks' => {
              'post_start' => [
                {
                  'name' => 'migrate',
                  'cmd' => 'rake db:migrate',
                  'instances' => '*'
                }
              ]
            }
          }
          result = subject.validate_options(data)
          expect(result.errors.key?('hooks')).to be_falsey
        end

        context 'item' do
          it 'must contain name' do
            result = subject.validate_options('hooks' =>
            {
              'post_start' => [
                {
                  'cmd' => 'rake db:migrate',
                  'instances' => '1'
                }
              ]
            })
            expect(result.errors.key?('hooks.post_start')).to be_truthy
          end

          it 'must contain cmd' do
            result = subject.validate_options('hooks' =>
            {
              'post_start' => [
                {
                  'name' => 'migrate',
                  'instances' => '1'
                }
              ]
            })
            expect(result.errors.key?('hooks.post_start')).to be_truthy
          end

          it 'must contain instance number or *' do
            result = subject.validate_options('hooks' =>
            {
              'post_start' => [
                { 'name' => 'migrate',
                  'cmd' => 'rake db:migrate'
                }
              ]
            })
            expect(result.errors.key?('hooks.post_start')).to be_truthy
            data = {
              'hooks' => {
                'post_start' => [
                  {
                    'name' => 'migrate',
                    'cmd' => 'rake db:migrate',
                    'instances' => 'all',
                    'oneshot' => true
                  }
                ]
              }
            }
            result = subject.validate_options(data)
            expect(result.errors.key?('hooks.post_start')).to be_truthy
          end

          it 'may contain boolean oneshot' do
            data = {
              'hooks' => {
                'post_start' => [
                  {
                    'name' => 'migrate',
                    'cmd' => 'rake db:migrate',
                    'instances' => '*',
                    'oneshot' => 'true'
                  }
                ]
              }
            }
            result = subject.validate_options(data)
            expect(result.errors.key?('hooks.post_start')).to be_truthy
          end
        end

        it 'validates volumes is array' do
          result = subject.validate_options('volumes' => '/app')
          expect(result.errors.key?('volumes')).to be_truthy

          result = subject.validate_options('volumes' => ['/app'])
          expect(result.errors.key?('volumes')).to be_falsey
        end

        it 'validates volumes_from is array' do
          result = subject.validate_options('volumes_from' => 'mysql_data')
          expect(result.errors.key?('volumes_from')).to be_truthy

          result = subject.validate_options('volumes_from' => ['mysql_data'])
          expect(result.errors.key?('volumes_from')).to be_falsey
        end
      end
    end

    context 'validates health_check' do
      it 'validates health_check' do
        result = subject.validate_options('health_check' => {})
        expect(result.errors.key?('health_check')).to be_truthy
      end

      it 'validates health_check port ' do
        result = subject.validate_options('health_check' => { 'protocol' => 'http', 'port' => 'abc'})
        expect(result.errors.key?('health_check')).to be_truthy

        result = subject.validate_options('health_check' => { 'protocol' => 'http', 'port' => 8080})
        expect(result.errors.key?('health_check')).to be_falsey
      end

      it 'validates health_check uri' do
        result = subject.validate_options('health_check' => { 'protocol' => 'http', 'port' => 8080, 'uri' => 'foobar'})
        expect(result.errors.key?('health_check')).to be_truthy

        result = subject.validate_options('health_check' => { 'protocol' => 'http', 'port' => 8080, 'uri' => '/health/foo/bar'})
        expect(result.errors.key?('health_check')).to be_falsey
      end

      it 'validates health_check protocol' do
        result = subject.validate_options('health_check' => { 'protocol' => 'foo', 'port' => 8080, 'uri' => 'foobar'})
        expect(result.errors.key?('health_check')).to be_truthy

        result = subject.validate_options('health_check' => { 'protocol' => 'tcp', 'port' => 3306 })
        expect(result.errors.key?('health_check')).to be_falsey
      end
    end
  end
end
