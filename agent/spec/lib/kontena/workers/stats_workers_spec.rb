require_relative '../../../spec_helper'

describe Kontena::Workers::StatsWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to agent:node_info channel' do
      expect(subject.wrapped_object).to receive(:on_node_info)
      Celluloid::Notifications.publish('agent:node_info')
      sleep 0.01
    end
  end

  describe '#on_node_info' do
    it 'initializes statsd client if node has statsd config' do
      info = {
        'grid' => {
          'stats' => {
            'statsd' => {
              'server' => '192.168.24.33',
              'port' => 8125
            }
          }
        }
      }
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:node_info', info)
      expect(subject.statsd).not_to be_nil
    end

    it 'does not initialize statsd if no statsd config exists' do
      info = {
        'grid' => {
          'stats' => {}
        }
      }
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:node_info', info)
      expect(subject.statsd).to be_nil
    end
  end

  describe '#send_statsd_metrics' do
    let(:event) do
      {
        id: 'aaaaaa',
        spec: {
          labels: {
            :'io.kontena.service.name' => 'foobar'
          }
        },
        cpu: {
          usage_pct: 12.32
        },
        memory: {
          usage: 24 * 1024 * 1024
        },
        filesystem: [],
        diskio: [],
        network: []
      }
    end

    let(:statsd) do
      spy(:statsd)
    end

    it 'sends statsd metrics' do
      allow(subject.wrapped_object).to receive(:statsd).and_return(statsd)
      expect(statsd).to receive(:gauge)
      subject.send_statsd_metrics('foobar', event)
    end
  end

describe '#send_container_stats' do
    let(:event) do
      {
        "id": "a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e",
        "name": "/system.slice/docker-a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e.scope",
        "aliases": [
          "weave",
          "a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e"
        ],
        "namespace": "docker",
        "labels": {
          "works.weave.role": "system"
        },
        "spec": "spec",
        "stats": [
          {
            "timestamp": "2016-05-31T08:46:40.31624557Z",
            "cpu": {
              "usage": {
                "total": 10,
                "per_cpu_usage": [
                  10
                ],
                "user": 10,
                "system": 10
              },
              "load_average": 0
            },
            "diskio": {
            },
            "memory": {
              "usage": 123248640,
              "cache": 11108352,
              "rss": 112140288,
              "working_set": 121257984
            },
            "network": {
              "name": "eth0",
              "rx_bytes": 274156082
            },
            "filesystem": [
              {
                "device": "/dev/sda9",
                "type": "vfs",
                "capacity": 16718393344,
                "usage": 18911232
              }
            ],
          },
          {
            "timestamp": "2016-05-31T08:47:15.906910438Z",
            "cpu": {
              "usage": {
                "total": 20,
                "per_cpu_usage": [
                  20
                ],
                "user": 20,
                "system": 20
              },
              "load_average": 0
            },
            "diskio": {},
            "memory": {
              "usage": 1024,
              "cache": 11108352,
              "rss": 112140288,
              "working_set": 2048,
            },
            "network": {
              "name": "eth0",
              "rx_bytes": 274156226
            },
            "filesystem": [
              {
                "device": "/dev/sda9",
                "type": "vfs",
                "capacity": 16718393344,
                "usage": 18911232
              }
            ]
          }
        ]
      }
    end

    it 'sends container stats' do
      #allow(subject.wrapped_object).to receive(:statsd).and_return(statsd)
      #expect(statsd).to receive(:gauge)
      expect(subject.wrapped_object).to receive(:send_statsd_metrics).with('weave', hash_including({
          id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e',
          spec: 'spec',
          cpu: {
            usage: 10,
            usage_pct: 0.0
          },
          memory: {
            usage: 1024,
            working_set: 2048
          },
          filesystem: event.dig(:stats, -1, :filesystem),
          diskio: event.dig(:stats, -1, :diskio),
          network: event.dig(:stats, -1, :network)
        }
      ))
      subject.send_container_stats(event)
    end

    it 'does not fail on missing stats' do
      #allow(subject.wrapped_object).to receive(:statsd).and_return(statsd)
      #expect(statsd).to receive(:gauge)
      event[:stats][-1][:cpu][:usage][:per_cpu_usage] = nil
      expect(subject.wrapped_object).to receive(:send_statsd_metrics).with('weave', hash_including({
          id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e',
          spec: 'spec',
          cpu: {
            usage: 10,
            usage_pct: 0.0
          },
          memory: {
            usage: 1024,
            working_set: 2048
          },
          filesystem: event.dig(:stats, -1, :filesystem),
          diskio: event.dig(:stats, -1, :diskio),
          network: event.dig(:stats, -1, :network)
        }
      ))
      subject.send_container_stats(event)
    end
  end

end
