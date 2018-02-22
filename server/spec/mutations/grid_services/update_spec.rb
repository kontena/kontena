describe GridServices::Update do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:stack) {Stack.create!(name: 'foo', grid: grid)}
  let(:redis_service) { GridService.create(grid: grid, stack: stack, name: 'redis', image_name: 'redis:2.8')}

  describe '#run' do
    it 'updates env variables' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.to change{ redis_service.reload.env }.to(['FOO=bar'])
    end

    it 'updates revision' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.to change{ redis_service.reload.revision }.to(2)
    end

    it 'updates image' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            image: 'redis:3.0'
        ).run
      }.to change{ redis_service.reload.image_name }.to('redis:3.0')
    end

    it 'does not update revision when nothing changes' do
      redis_service.env = ['FOO=bar']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.not_to change{ redis_service.reload.revision }
    end

    it 'updates affinity variables' do
      redis_service.affinity = ['az==a1', 'disk==ssd']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            affinity: ['az==b1']
        ).run
      }.to change{ redis_service.reload.affinity }.to(['az==b1'])
    end

    it 'updates stop_grace_period' do
      redis_service.stop_grace_period = 15
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            stop_grace_period: '1m23s'
        ).run
      }.to change{ redis_service.reload.stop_grace_period }.to(83)
    end

    context 'deploy_opts' do
      it 'updates wait_for_port' do
        described_class.new(
            grid_service: redis_service,
            deploy_opts: {
              wait_for_port: 6379
            }
        ).run
        redis_service.reload
        expect(redis_service.deploy_opts.wait_for_port).to eq(6379)
      end

      it 'allows to delete wait_for_port' do
        redis_service.deploy_opts.wait_for_port = 6379
        redis_service.save
        described_class.new(
            grid_service: redis_service,
            deploy_opts: {
              wait_for_port: nil
            }
        ).run
        redis_service.reload
        expect(redis_service.deploy_opts.wait_for_port).to be_nil
      end
    end

    context 'health_check' do
      it 'updates health check port & protocol' do
        described_class.new(
            grid_service: redis_service,
            health_check: {
              port: 80,
              protocol: 'http'
            }
        ).run
        redis_service.reload
        expect(redis_service.health_check.port).to eq(80)
        expect(redis_service.health_check.protocol).to eq('http')
      end

      it 'allows to update health check partially' do
        redis_service.health_check = {
          port: 80, protocol: 'http'
        }
        redis_service.save
        described_class.new(
            grid_service: redis_service,
            health_check: {
              port: 80,
              protocol: 'http',
              uri: '/health'
            }
        ).run
        redis_service.reload
        expect(redis_service.health_check.port).to eq(80)
        expect(redis_service.health_check.protocol).to eq('http')
        expect(redis_service.health_check.uri).to eq('/health')
      end

      it 'removes health check if port & protocol are nils' do
        described_class.new(
            grid_service: redis_service,
            health_check: {
              port: nil,
              protocol: nil
            }
        ).run
        redis_service.reload
        expect(redis_service.health_check.port).to be_nil
        expect(redis_service.health_check.protocol).to be_nil
      end
    end

    context 'secrets' do
      it 'fails validating secret existence' do
        outcome = described_class.new(
            grid_service: redis_service,
            secrets: [
              {secret: 'NON_EXISTING_SECRET', name: 'SOME_SECRET'}
            ]
        ).run
        expect(outcome.success?).to be(false)
      end

      it 'validates secret existence' do
        GridSecret.create!(grid: grid, name: 'EXISTING_SECRET', value: 'secret')
        outcome = described_class.new(
            grid_service: redis_service,
            secrets: [
              {secret: 'EXISTING_SECRET', name: 'SOME_SECRET'}
            ]
        ).run
        expect(outcome.success?).to be(true)
      end

      context 'for a service with secrets' do
        let(:secret1) { GridSecret.create!(grid: grid, name: 'SECRET1', value: 'secret') }
        let(:secret2) { GridSecret.create!(grid: grid, name: 'SECRET2', value: 'secret') }
        let(:secret3) { GridSecret.create!(grid: grid, name: 'SECRET3', value: 'secret') }

        let(:service) {
          GridService.create(grid: grid, stack: stack, name: 'redis',
            image_name: 'redis:2.8',
            secrets: [
              {secret: secret1.name, name: 'SECRET1'},
              {secret: secret2.name, name: 'SECRET2'},
            ],
          )
        }

        it 'does not change existing secrets' do
          subject = described_class.new(
              grid_service: service,
              secrets: [
                {secret: secret1.name, name: 'SECRET1'},
                {secret: secret2.name, name: 'SECRET2'},
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}
        end

        it 'changes secrets' do
          subject = described_class.new(
              grid_service: service,
              secrets: [
                {secret: secret1.name, name: 'SECRET1'},
                {secret: secret2.name, name: 'SECRET2b'},
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}
        end

        it 'removes secrets' do
          subject = described_class.new(
              grid_service: service,
              secrets: [
                {secret: secret1.name, name: 'SECRET1'},
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}

          expect(service.reload.secrets.map{|gss| gss.secret}).to eq ['SECRET1']
        end
      end

      context 'for a service with multiple names for the same secret' do
        let(:secret1) { GridSecret.create!(grid: grid, name: 'SECRET1', value: 'secret') }

        let(:service) {
          GridService.create(grid: grid, stack: stack, name: 'redis',
            image_name: 'redis:2.8',
            secrets: [
              {secret: secret1.name, name: 'SECRET1'},
              {secret: secret1.name, name: 'SECRET2'},
            ],
          )
        }

        it 'keeps both secret names' do
          subject = described_class.new(
              grid_service: service,
              secrets: [
                {secret: secret1.name, name: 'SECRET1'},
                {secret: secret1.name, name: 'SECRET2'},
              ]
          )
          outcome = nil
          expect {
            outcome = subject.run

            expect(outcome).to be_success
          }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}

          expect(outcome.result.secrets.map{|s| s.attributes}).to match [
            hash_including(
              'secret' => 'SECRET1',
              'type' => 'env',
              'name' => 'SECRET1',
            ),
            hash_including(
              'secret' => 'SECRET1',
              'type' => 'env',
              'name' => 'SECRET2',
            ),
          ]

        end
      end
    end

    context 'for a service with certificates' do
      let(:service) {
        GridService.create(grid: grid, stack: stack, name: 'redis',
          image_name: 'redis:2.8',
          certificates: [
            {subject: certificate.subject, name: 'SSL_CERT'},
            {subject: certificate2.subject, name: 'SSL_CERT2'}
          ],
        )
      }

      let :certificate do
        Certificate.create!(grid: grid,
          subject: 'kontena.io',
          valid_until: Time.now + 90.days,
          private_key: 'private_key',
          certificate: 'certificate')
      end

      let :certificate2 do
        Certificate.create!(grid: grid,
          subject: 'www.kontena.io',
          valid_until: Time.now + 90.days,
          private_key: 'private_key',
          certificate: 'certificate')
      end

      it 'does not change existing certs' do
        subject = described_class.new(
            grid_service: service,
            certificates: [
              {subject: certificate.subject, name: 'SSL_CERT'},
              {subject: certificate2.subject, name: 'SSL_CERT2'}
            ]
        )
        expect {
          expect(outcome = subject.run).to be_success
        }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}
      end

      it 'changes existing certs' do
        subject = described_class.new(
            grid_service: service,
            certificates: [
              {subject: certificate.subject, name: 'SSL_CERT'},
              {subject: certificate2.subject, name: 'SSL_CERT2_FOO'}
            ]
        )
        expect {
          expect(outcome = subject.run).to be_success
        }.to change{service.reload.revision}.and change{service.reload.updated_at}
      end

      it 'removes certificate' do
        subject = described_class.new(
            grid_service: service,
            certificates: [
              {subject: certificate.subject, name: 'SSL_CERT'}
            ]
        )
        expect {
          expect(outcome = subject.run).to be_success
        }.to change{service.reload.revision}.and change{service.reload.updated_at}

        expect(service.reload.certificates.map{|c| c.subject}).to eq ['kontena.io']
      end

      it 'fails with invalid certificate' do
        subject = described_class.new(
            grid_service: service,
            certificates: [
              {subject: 'www.kotnena.io', name: 'SSL_CERT'},
            ]
        )
        expect {
          expect(outcome = subject.run).to_not be_success
        }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}

        expect(service.reload.certificates.map{|c| c.subject}).to eq ['kontena.io', 'www.kontena.io']
      end
    end

    context 'hooks' do
      context 'for a service with hooks' do
        let(:service) {
          GridService.create(grid: grid, stack: stack, name: 'redis',
            image_name: 'redis:2.8',
            hooks: [
              GridServiceHook.new(
                name: 'foo',
                type: 'post_start',
                cmd: 'sleep 1',
                instances: ['*'],
                oneshot: false
              ),
            ],
          )
        }

        it 'does not change existing hooks' do
          subject = described_class.new(
            grid_service: service,
            hooks: {
              post_start: [
                {
                  name: 'foo',
                  cmd: 'sleep 1',
                  instances: "*",
                  oneshot: false
                }
              ]
            }
          )

          expect {
            expect(outcome = subject.run).to be_success
          }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}
        end
      end
    end

    context 'volumes' do
      context 'service with volumes' do
        let(:service) {
          GridService.create(grid: grid, stack: stack, name: 'redis',
            image_name: 'redis:2.8',
            service_volumes: [
              {bind_mount: '/foo', path: '/foo', flags: ''},
            ],
          )
        }

        it 'keeps existing volumes' do
          subject = described_class.new(
              grid_service: service,
              volumes: [
                '/foo:/foo',
              ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}

          expect(service.service_volumes.first.to_s).to eq '/foo:/foo'

        end

        it 'changes volumes' do
          subject = described_class.new(
              grid_service: service,
              volumes: [
                '/foo2:/foo',
              ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}
          expect(service.service_volumes.first.to_s).to eq '/foo2:/foo'
        end

        it 'changes volume flags' do
          subject = described_class.new(
              grid_service: service,
              volumes: [
                '/foo:/foo:ro',
              ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}
          expect(service.service_volumes.first.to_s).to eq '/foo:/foo:ro'
        end

        it 'adds volumes' do
          subject = described_class.new(
              grid_service: service,
              volumes: [
                '/foo:/foo',
                '/foo2:/foo2',
              ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}
          expect(service.service_volumes.map{|sv| sv.to_s}).to eq ['/foo:/foo', '/foo2:/foo2']
        end

        it 'deletes volumes' do
          subject = described_class.new(
              grid_service: service,
              volumes: [
              ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}

          expect(service.service_volumes.map{|sv| sv.to_s}).to eq []
        end
      end

      context 'stateless service' do
        it 'allows to add non-named volume' do
          outcome = described_class.new(
            grid_service: redis_service,
            volumes: ['/foo']
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.first.path).to eq('/foo')
        end

        it 'allows to add named volume' do
          volume = Volume.create!(name: 'foo', grid: grid, scope: 'instance')
          outcome = described_class.new(
            grid_service: redis_service,
            volumes: ['foo:/foo']
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.first.volume).to eq(volume)
        end

        it 'allows to add bind mounted volume' do
          outcome = described_class.new(
            grid_service: redis_service,
            volumes: ['/foo:/foo']
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.first.path).to eq('/foo')
          expect(outcome.result.service_volumes.first.bind_mount).to eq('/foo')
        end
      end

      context 'stateful service' do
        let(:stateful_service) do
          outcome = GridServices::Create.run(grid: grid, stack: stack, name: 'redis', image: 'redis:2.8', stateful: true, volumes: ['/data'])
          outcome.result
        end

        let! :volume do
          Volume.create!(name: 'foo', grid: grid, scope: 'container')
        end

        it 'does not allow to add non-named volume' do
          outcome = described_class.new(
            grid_service: stateful_service,
            volumes: ['/data', '/foo']
          ).run
          expect(outcome).to_not be_success
          expect(outcome.errors.message).to eq({ 'volumes' => ["Adding a new anonymous volume (/foo) to a stateful service is not supported"] })

        end

        it 'allows to add named volume' do
          outcome = described_class.new(
            grid_service: stateful_service,
            volumes: ['/data', 'foo:/foo']
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.count).to eq(2)
        end

        it 'allows to add bind mounted volume' do
          outcome = described_class.new(
            grid_service: stateful_service,
            volumes: ['/data', '/foo:/foo']
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.count).to eq(2)
        end

        it 'allows to remove a volume' do
          outcome = described_class.new(
            grid_service: stateful_service,
            volumes: []
          ).run
          expect(outcome).to be_success
          expect(outcome.result.service_volumes.count).to eq(0)
        end
      end
    end

    context 'volumes_from' do
      context 'stateless service' do
        it 'allows to update volumes_from' do
          outcome = described_class.new(
            grid_service: redis_service,
            volumes_from: ['data-1']
          ).run
          expect(outcome.success?).to be_truthy
          expect(outcome.result.volumes_from).to eq(['data-1'])
        end
      end

      context 'stateful service' do
        let(:stateful_service) do
          outcome = GridServices::Create.run(grid: grid, name: 'redis', image: 'redis:2.8', stateful: true, volumes: ['/data'])
          outcome.result
        end

        it 'does not allow to update volumes_from' do
          outcome = described_class.new(
            grid_service: stateful_service,
            volumes_from: ['data-1']
          ).run
          expect(outcome).to_not be_success
          expect(outcome.errors.message).to eq({ 'volumes_from' => "Cannot combine stateful & volumes_from" })
        end
      end
    end

    describe 'links' do
      context 'for a service with links' do
        let(:linked_service2) { GridService.create!(grid: grid, stack: stack, name: 'redis2', image_name: 'redis:2.8') }
        let(:linked_service3) { GridService.create!(grid: grid, stack: stack, name: 'redis3', image_name: 'redis:2.8') }
        let(:secret) { GridSecret.create!(grid: grid, name: 'EXISTING_SECRET', value: 'secret') }
        let(:service) {
          GridService.create(grid: grid, stack: stack, name: 'redis',
            image_name: 'redis:2.8',
            grid_service_links: [
              {linked_grid_service: linked_service2, alias: 'redis2'},
            ],
          )
        }

        it 'keeps existing links' do
          linked_service2

          subject = described_class.new(
              grid_service: service,
              links: [
                {name: 'redis2', alias: 'redis2'}
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to not_change{service.reload.revision}.and not_change{service.reload.updated_at}
        end

        it 'clears links' do
          subject = described_class.new(
              grid_service: service,
              links: [ ],
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}.and change{service.reload.grid_service_links.count}.from(1).to(0)
        end

        it 'deletes links' do
          service.link_to(linked_service3)
          expect(service.grid_service_links.count).to eq 2

          subject = described_class.new(
              grid_service: service,
              links: [
                {name: 'redis2', alias: 'redis2'}
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}.and change{service.reload.grid_service_links.count}.from(2).to(1)
        end

        it 'changes links' do
          linked_service2
          linked_service3

          subject = described_class.new(
              grid_service: service,
              links: [
                {name: 'redis3', alias: 'redis3'}
              ]
          )
          expect {
            expect(outcome = subject.run).to be_success
          }.to change{service.reload.revision}.and change{service.reload.updated_at}.and change{service.reload.grid_service_links.first.alias}.from('redis2').to('redis3')
        end
      end
    end

    context 'for a service with a very long name' do
      let(:service) { GridService.create(grid: grid, name: 'xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxx38', image_name: 'redis:2.8')}

      it 'allows scaling to single-digit instances' do
        outcome = described_class.run(
            grid_service: service,
            instances: 9,
        )
        expect(outcome).to be_success
      end

      it 'does not allow scaling to double-digit instances' do
        outcome = described_class.run(
            grid_service: service,
            instances: 10,
        )
        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'name' => 'Total grid service name length 65 is over limit (64): xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxxxx38-10.test-grid.kontena.local'
      end
    end
  end

  describe '#build_grid_service_hooks' do
    let(:subject) do
      described_class.new(
        grid_service: redis_service,
        hooks: {
          post_start: [
            {
              name: 'foo',
              cmd: 'sleep 10',
              instances: ["1", "2"],
              oneshot: false
            }
          ]
        }
      )
    end

    it 'builds hook' do
      hooks = subject.build_grid_service_hooks([])
      expect(hooks.size).to eq(1)
      expect(hooks[0].cmd).to eq('sleep 10')
    end

    it 'updates existing hook' do
      org_hook = GridServiceHook.new(
        name: 'foo',
        type: 'post_start',
        cmd: 'sleep 1',
        instances: ['*'],
        oneshot: false
      )
      redis_service.hooks << org_hook
      redis_service.save
      hooks = subject.build_grid_service_hooks(redis_service.hooks.to_a)
      expect(hooks.size).to eq(1)
      expect(hooks[0].id).to eq(org_hook.id)
      expect(hooks[0].cmd).to eq('sleep 10')
    end
  end

  describe '#build_grid_service_envs' do
    let(:redis_service) do
      GridService.create!(
        grid: grid,
        name: 'redis',
        image_name: 'redis:2.8',
        env: [
          'FOO=bar',
          'BAR=baz'
        ]
      )
    end
    let(:subject) do
      described_class.new(
        grid_service: redis_service
      )
    end

    it 'appends to env' do
      env = redis_service.env.dup
      env << 'TEST=test'
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(3)
      expect(env[2]).to eq('TEST=test')
    end

    it 'modifies env' do
      env = redis_service.env.dup
      env[1] = 'BAR=bazzz'
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(2)
      expect(env[1]).to eq('BAR=bazzz')
    end

    it 'does not modify env if value nil' do
      env = redis_service.env.dup
      env[1] = 'BAR='
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(2)
      expect(env[1]).to eq('BAR=baz')
    end
  end
end
