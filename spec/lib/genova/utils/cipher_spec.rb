require 'rails_helper'

module Genova
  module Utils
    describe Cipher do
      let(:kms_client_mock) { double(Aws::KMS::Client) }
      let(:cipher) { Utils::Cipher.new }

      before do
        allow(Aws::KMS::Client).to receive(:new).and_return(kms_client_mock)
      end

      describe 'encrypt' do
        context 'when valid master key' do
          let(:encrypt_response) { Aws::KMS::Types::EncryptResponse.new(ciphertext_blob: 'encrypted_value') }

          it 'should be return encrypted value' do
            allow(kms_client_mock).to receive(:encrypt).and_return(encrypt_response)
            expect(cipher.encrypt('master_key', 'xxx')).to eq('${ZW5jcnlwdGVkX3ZhbHVl}')
          end
        end

        context 'when invalid master key' do
          it 'should be return error' do
            allow(kms_client_mock).to receive(:encrypt).and_raise(RuntimeError)
            expect { cipher.encrypt('master_key', 'xxx') }.to raise_error(Exceptions::KmsEncryptError)
          end
        end
      end

      describe 'decrypt' do
        context 'when valid encrypted value' do
          let(:decrypt_response) { Aws::KMS::Types::DecryptResponse.new(plaintext: 'decrypted_value') }

          it 'should be return encrypted value' do
            allow(Base64).to receive(:strict_decode64)
            allow(kms_client_mock).to receive(:decrypt).and_return(decrypt_response)
            expect(cipher.decrypt('${xxx}')).to eq('decrypted_value')
          end
        end

        context 'when invalid encrypted value' do
          context 'when valid value format' do
            it 'should be return error' do
              allow(kms_client_mock).to receive(:decrypt).and_raise(RuntimeError)
              expect { cipher.decrypt('${xxx}') }.to raise_error(Exceptions::KmsDecryptError)
            end
          end

          context 'when invalid value format' do
            it 'should be return error' do
              expect { cipher.decrypt('xxx') }.to raise_error(Exceptions::KmsDecryptError)
            end
          end
        end
      end
    end
  end
end
