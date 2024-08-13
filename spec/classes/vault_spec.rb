# frozen_string_literal: true

require 'spec_helper'

describe 'openbao' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { override_facts(os_facts, processors: { count: 3 }) }

      context 'openbao class with simple configuration' do
        let(:params) do
          {
            storage: {
              'file' => {
                'path' => '/data/openbao'
              }
            },
            listener: {
              'tcp' => {
                'address'     => '127.0.0.1:8200',
                'tls_disable' => 1
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('openbao') }

        it { is_expected.to contain_class('openbao::params') }
        it { is_expected.to contain_class('openbao::install').that_comes_before('Class[openbao::config]') }
        it { is_expected.to contain_class('openbao::config') }
        it { is_expected.to contain_class('openbao::service').that_subscribes_to('Class[openbao::config]') }

        it {
          is_expected.to contain_service('openbao').
            with_ensure('running').
            with_enable(true)
        }

        it { is_expected.to contain_user('openbao') }
        it { is_expected.to contain_group('openbao') }
        it { is_expected.not_to contain_file('/data/openbao') }

        context 'when not managing user and group' do
          let(:params) do
            {
              manage_user: false,
              manage_group: false
            }
          end

          it { is_expected.not_to contain_user('openbao') }
          it { is_expected.not_to contain_group('openbao') }
        end

        it {
          is_expected.to contain_file('/etc/openbao/config.json').
            with_owner('openbao').
            with_group('openbao')
        }

        context 'openbao JSON config' do
          subject { param_value(catalogue, 'File', '/etc/openbao/config.json', 'content') }

          it {
            is_expected.to include_json(
              storage: {
                file: {
                  path: '/data/openbao'
                }
              }
            )
          }

          it {
            is_expected.to include_json(
              listener: {
                tcp: {
                  address: '127.0.0.1:8200',
                  tls_disable: 1
                }
              }
            )
          }

          it 'excludes unconfigured config options' do
            expect(subject).not_to include_json(
              ha_storage: exist,
              seal: exist,
              disable_cache: exist,
              telemetry: exist,
              default_lease_ttl: exist,
              max_lease_ttl: exist,
              disable_mlock: exist,
              ui: exist,
              api_addr: exist
            )
          end
        end

        it { is_expected.to contain_file('openbao_binary').with_mode('0755') }

        context 'when disable mlock' do
          let(:params) do
            {
              disable_mlock: true
            }
          end

          it { is_expected.not_to contain_file_capability('openbao_binary_capability') }

          it {
            expect(param_value(catalogue, 'File', '/etc/openbao/config.json', 'content')).to include_json(
              disable_mlock: true
            )
          }
        end

        context 'when api address is set' do
          let(:params) do
            {
              api_addr: 'something'
            }
          end

          it {
            expect(param_value(catalogue, 'File', '/etc/openbao/config.json', 'content')).to include_json(
              api_addr: 'something'
            )
          }
        end

        context 'when installed from archive' do
          let(:params) { { install_method: 'archive' } }

          it {
            is_expected.to contain_archive('/tmp/openbao.zip').
              that_comes_before('File[openbao_binary]')
          }

          it {
            is_expected.to contain_file('/etc/openbao').
              with_ensure('directory').
              with_purge('true').
              with_recurse('true').
              with_owner('openbao').
              with_group('openbao')
          }

          context 'when installed with default download options' do
            let(:params) do
              super().merge(version: '0.7.0')
            end

            it {
              is_expected.to contain_archive('/tmp/openbao.zip').
                with_source('https://releases.hashicorp.com/openbao/0.7.0/openbao_0.7.0_linux_amd64.zip')
            }
          end

          context 'when specifying a custom download params' do
            let(:params) do
              super().merge(
                version: '0.6.0',
                download_url_base: 'http://my_site.example.com/openbao/',
                package_name: 'openbaobinary',
                download_extension: 'tar.gz'
              )
            end

            it {
              is_expected.to contain_archive('/tmp/openbao.zip').
                with_source('http://my_site.example.com/openbao/0.6.0/openbaobinary_0.6.0_linux_amd64.tar.gz')
            }
          end

          context 'when installed from download url' do
            let(:params) do
              super().merge(download_url: 'http://example.com/openbao.zip')
            end

            it {
              is_expected.to contain_archive('/tmp/openbao.zip').
                with_source('http://example.com/openbao.zip')
            }
          end

          it {
            is_expected.to contain_file_capability('openbao_binary_capability').
              with_ensure('present').
              with_capability('cap_ipc_lock=ep').
              that_subscribes_to('File[openbao_binary]')
          }

          context 'when not managing file capabilities' do
            let(:params) { { manage_file_capabilities: false } }

            it { is_expected.not_to contain_file_capability('openbao_binary_capability') }
          end
        end

        context 'When asked not to manage the repo' do
          let(:params) do
            {
              manage_repo: false
            }
          end

          case os_facts[:os]['family']
          when 'Debian'
            it { is_expected.not_to contain_apt__source('OriginalDeveloper') }
          when 'RedHat'
            it { is_expected.not_to contain_yumrepo('OriginalDeveloper') }
          end
        end

        context 'When asked to manage the repo but not to install using repo' do
          let(:params) do
            {
              install_method: 'archive',
              manage_repo: true
            }
          end

          case os_facts[:os]['family']
          when 'Debian'
            it { is_expected.not_to contain_apt__source('OriginalDeveloper') }
          when 'RedHat'
            it { is_expected.not_to contain_yumrepo('OriginalDeveloper') }
          end
        end

        context 'When asked to manage the repo and to install as repo' do
          let(:params) do
            {
              install_method: 'repo',
              manage_repo: true
            }
          end

          if os_facts[:os]['family'] == 'Archlinux'
            it { is_expected.not_to compile }
          else
            it { is_expected.not_to contain_file('/etc/openbao') }
            it { is_expected.to contain_file('/etc/openbao.d/config.json') }
          end

          case os_facts[:os]['family']
          when 'Debian'
            it { is_expected.to contain_apt__source('OriginalDeveloper') }
          when 'RedHat'
            it { is_expected.to contain_yumrepo('OriginalDeveloper') }
          end
        end

        context 'when installed from package repository' do
          let(:params) do
            {
              install_method: 'repo',
              package_name: 'openbao',
              package_ensure: 'installed'
            }
          end

          it { is_expected.to contain_package('openbao') }
          it { is_expected.not_to contain_file_capability('openbao_binary_capability') }

          context 'when managing file capabilities' do
            let(:params) do
              super().merge(
                manage_file_capabilities: true
              )
            end

            it { is_expected.to contain_file_capability('openbao_binary_capability') }
            it { is_expected.to contain_package('openbao').that_notifies(['File_capability[openbao_binary_capability]']) }
          end
        end
      end

      context 'when specifying ui to be true' do
        let(:params) do
          {
            enable_ui: true
          }
        end

        it {
          expect(param_value(catalogue, 'File', '/etc/openbao/config.json', 'content')).to include_json(
            ui: true
          )
        }
      end

      context 'when specifying config mode' do
        let(:params) do
          {
            config_mode: '0700'
          }
        end

        it { is_expected.to contain_file('/etc/openbao/config.json').with_mode('0700') }
      end

      context 'when specifying an array of listeners' do
        let(:params) do
          {
            listener: [
              { 'tcp' => { 'address' => '127.0.0.1:8200' } },
              { 'tcp' => { 'address' => '0.0.0.0:8200' } }
            ]
          }
        end

        it {
          expect(param_value(catalogue, 'File', '/etc/openbao/config.json', 'content')).to include_json(
            listener: [
              {
                tcp: {
                  address: '127.0.0.1:8200'
                }
              },
              {
                tcp: {
                  address: '0.0.0.0:8200'
                }
              }
            ]
          )
        }
      end

      context 'when specifying manage_service' do
        let(:params) do
          {
            manage_service: false,
            storage: {
              'file' => {
                'path' => '/data/openbao'
              }
            }
          }
        end

        it {
          is_expected.not_to contain_service('openbao').
            with_ensure('running').
            with_enable(true)
        }
      end

      context 'when specifying manage_storage_dir and file storage backend' do
        let(:params) do
          {
            manage_storage_dir: true,
            storage: {
              'file' => {
                'path' => '/data/openbao'
              }
            }
          }
        end

        it {
          is_expected.to contain_file('/data/openbao').
            with_ensure('directory').
            with_owner('openbao').
            with_group('openbao')
        }
      end

      context 'when specifying manage_storage_dir and raft storage backend' do
        let(:params) do
          {
            manage_storage_dir: true,
            storage: {
              'raft' => {
                'path' => '/data/openbao'
              }
            }
          }
        end

        it {
          is_expected.to contain_file('/data/openbao').
            with_ensure('directory').
            with_owner('openbao').
            with_group('openbao')
        }
      end

      context 'when specifying manage_config_file = false' do
        let(:params) do
          {
            manage_config_file: false,
          }
        end

        it {
          is_expected.not_to contain_file('/etc/openbao/config.json')
        }
      end

      context 'when ensuring the service is disabled' do
        let(:params) do
          {
            service_enable: false,
            service_ensure: 'stopped'
          }
        end

        it {
          is_expected.to contain_service('openbao').
            with_ensure('stopped').
            with_enable(false)
        }
      end

      case os_facts[:os]['family']
      when 'RedHat'
        case os_facts[:os]['release']['major'].to_i
        when 7
          context 'RedHat >=7 specific' do
            context 'includes systemd init script' do
              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=openbao$}).
                  with_content(%r{^Group=openbao$}).
                  with_content(%r{Environment=GOMAXPROCS=3}).
                  with_content(%r{^ExecStart=/usr/local/bin/bao server -config=/etc/openbao/config.json $}).
                  with_content(%r{SecureBits=keep-caps}).
                  with_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end

            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/bao',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: 8
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/bao server -config=/opt/etc/openbao/config.json -log-level=info$})
              }
            end

            context 'with mlock disabled' do
              let(:params) do
                { disable_mlock: true }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=openbao$}).
                  with_content(%r{^Group=openbao$}).
                  with_content(%r{^ExecStart=/usr/local/bin/bao server -config=/etc/openbao/config.json $}).
                  without_content(%r{SecureBits=keep-caps}).
                  without_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end

            context 'includes systemd magic' do
              it { is_expected.to contain_class('systemd') }
            end

            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end
          end
        end
      when 'Debian'
        context 'on Debian OS family' do
          context 'install through repo with default service management' do
            let(:params) do
              {
                install_method: 'repo',
                manage_service_file: :undef
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/openbao') }
          end

          context 'install through repo without service management' do
            let(:params) do
              {
                install_method: 'repo',
                manage_service_file: false
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/openbao') }
          end

          context 'install through archive without service management' do
            let(:params) do
              {
                install_method: 'archive',
                manage_service_file: false
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/openbao') }
          end

          context 'on Debian based with systemd' do
            context 'includes systemd init script' do
              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=openbao$}).
                  with_content(%r{^Group=openbao$}).
                  with_content(%r{Environment=GOMAXPROCS=3}).
                  with_content(%r{^ExecStart=/usr/local/bin/bao server -config=/etc/openbao/config.json $}).
                  with_content(%r{SecureBits=keep-caps}).
                  with_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end

            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/openbao',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: 8
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/bao server -config=/opt/etc/openbao/config.json -log-level=info$})
              }
            end

            context 'with mlock disabled' do
              let(:params) do
                { disable_mlock: true }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/openbao.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# openbao systemd unit file}).
                  with_content(%r{^User=openbao$}).
                  with_content(%r{^Group=openbao$}).
                  with_content(%r{^ExecStart=/usr/local/bin/bao server -config=/etc/openbao/config.json $}).
                  without_content(%r{SecureBits=keep-caps}).
                  without_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end

            it { is_expected.to contain_systemd__unit_file('openbao.service') }

            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/openbao.service') }
            end

            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/openbao.service') }
            end
          end
        end
      when 'Archlinux'
        context 'defaults to repo install' do
          it { is_expected.to contain_file('openbao_binary').with_path('/bin/bao') }
          it { is_expected.not_to contain_file_capability('openbao_binary_capability') }
        end
      end
    end
  end
end
