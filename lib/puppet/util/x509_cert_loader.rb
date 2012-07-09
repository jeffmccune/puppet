require 'openssl'
require 'puppet/util'

module Puppet
  module Util
    class X509CertLoader
      def self.new_from_file(pem_file)
        new(File.read(pem_file))
      end

      def self.new_from_s(pem_s)
        new(pem_s)
      end

      def initialize(pem_s)
        @pem_cert_re = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
        @pem_s = pem_s
        self
      end

      # Return an array of OpenSSL::X509::Certificate instances
      def certificates
        @certificates ||= @pem_s.scan(@pem_cert_re).collect { |pem| OpenSSL::X509::Certificate.new(pem) }
      end
    end
  end
end
