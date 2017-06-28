require_relative '../test_helper'
require 'stringio'

module SymmetricEncryption
  class FileTest < Minitest::Test
    describe SymmetricEncryption::Keystore::Environment do
      let :key_encryption_key do
        rsa_key = SymmetricEncryption::KeyEncryptionKey.generate
        SymmetricEncryption::KeyEncryptionKey.new(rsa_key)
      end

      let :keystore do
        SymmetricEncryption::Keystore::Environment.new(key_env_var: 'TESTER_ENV_VAR', key_encryption_key: key_encryption_key)
      end

      after do
        # Cleanup generated encryption key files.
        `rm tmp/tester*`
      end

      describe '.new_cipher' do
        let :version do
          10
        end

        let :keystore do
          SymmetricEncryption::Keystore::Environment.new_cipher(
            cipher_name:        'aes-256-cbc',
            key_encryption_key: key_encryption_key,
            app_name:           'tester',
            environment:        'test',
            version:            version
          )
        end

        it 'increments the version' do
          assert_equal 11, keystore['version']
        end

        describe 'with 255 version' do
          let :version do
            255
          end

          it 'handles version wrap' do
            assert_equal 1, keystore['version']
          end
        end

        describe 'with 0 version' do
          let :version do
            0
          end

          it 'increments version' do
            assert_equal 1, keystore['version']
          end
        end

        it 'retains the env var name' do
          assert_equal "TESTER_TEST_V11", keystore['key_env_var']
        end

        it 'retains cipher_name' do
          assert_equal 'aes-256-cbc', keystore['cipher_name']
        end
      end

      describe '.new_config' do
        let :environments do
          %w(development test acceptance preprod production)
        end

        let :config do
          SymmetricEncryption::Keystore::Environment.new_config(
            app_name:     'tester',
            environments: environments,
            cipher_name:  'aes-128-cbc'
          )
        end

        it 'creates keys for each environment' do
          assert_equal environments, config.keys, config
        end

        it 'use test config for development and test' do
          assert_equal SymmetricEncryption::Keystore::Memory.dev_config, config['test']
          assert_equal SymmetricEncryption::Keystore::Memory.dev_config, config['development']
        end

        it 'each non test environment has a key encryption key' do
          (environments - %w(development test)).each do |env|
            assert config[env]['private_rsa_key'].include?('BEGIN RSA PRIVATE KEY'), "Environment #{env} is missing the key encryption key"
          end
        end

        it 'every environment has ciphers' do
          environments.each do |env|
            assert ciphers = config[env]['ciphers'], "Environment #{env} is missing ciphers: #{config[env].inspect}"
            assert_equal 1, ciphers.size
          end
        end

        it 'creates an encrypted key file for all non-test environments' do
          (environments - %w(development test)).each do |env|
            assert ciphers = config[env]['ciphers'], "Environment #{env} is missing ciphers: #{config[env].inspect}"
            assert file_name = ciphers.first['key_env_var'], "Environment #{env} is missing key_env_var: #{ciphers.inspect}"
          end
        end
      end

      describe '#read' do
        it 'reads the key' do
          ENV["TESTER_ENV_VAR"] = keystore.encoder.encode(key_encryption_key.encrypt('TEST'))
          assert_equal 'TEST', keystore.read
        end
      end

    end
  end
end
