require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'thread'

require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_revocation_list'
require 'puppet/util/x509_cert_loader'

class Puppet::Network::HTTP::WEBrick
  def initialize(args = {})
    @listening = false
    @mutex = Mutex.new
  end

  def listen(args = {})
    raise ArgumentError, ":address must be specified." unless args[:address]
    raise ArgumentError, ":port must be specified." unless args[:port]

    arguments = {:BindAddress => args[:address], :Port => args[:port]}
    arguments.merge!(setup_logger)
    arguments.merge!(setup_ssl)

    @server = WEBrick::HTTPServer.new(arguments)
    @server.listeners.each { |l| l.start_immediately = false }

    @server.mount('/', Puppet::Network::HTTP::WEBrickREST, :this_value_is_apparently_necessary_but_unused)

    @mutex.synchronize do
      raise "WEBrick server is already listening" if @listening
      @listening = true
      @thread = Thread.new {
        @server.start { |sock|
          raise "Client disconnected before connection could be established" unless IO.select([sock],nil,nil,6.2)
          sock.accept
          @server.run(sock)
        }
      }
      sleep 0.1 until @server.status == :Running
    end
  end

  def unlisten
    @mutex.synchronize do
      raise "WEBrick server is not listening" unless @listening
      @server.shutdown
      @thread.join
      @server = nil
      @listening = false
    end
  end

  def listening?
    @mutex.synchronize do
      @listening
    end
  end

  # Configure our http log file.
  def setup_logger
    # Make sure the settings are all ready for us.
    Puppet.settings.use(:main, :ssl, :application)

    if Puppet.run_mode.master?
      file = Puppet[:masterhttplog]
    else
      file = Puppet[:httplog]
    end

    # open the log manually to prevent file descriptor leak
    file_io = ::File.open(file, "a+")
    file_io.sync = true
    if defined?(Fcntl::FD_CLOEXEC)
      file_io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end

    args = [file_io]
    args << WEBrick::Log::DEBUG if Puppet::Util::Log.level == :debug

    logger = WEBrick::Log.new(*args)
    return :Logger => logger, :AccessLog => [
      [logger, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
      [logger, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
    ]
  end

  # Add all of the ssl cert information.
  def setup_ssl
    results = {}

    # Get the cached copy.  We know it's been generated, too.
    host = Puppet::SSL::Host.localhost

    raise Puppet::Error, "Could not retrieve certificate for #{host.name} and not running on a valid certificate authority" unless host.certificate

    results[:SSLPrivateKey] = host.key.content
    results[:SSLCertificate] = host.certificate.content
    results[:SSLStartImmediately] = true
    results[:SSLEnable] = true

    raise Puppet::Error, "Could not find CA certificate" unless Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME)

    results[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER

    # JJM Webrick accepts these options
    # lib/ruby/1.9.1/webrick/ssl.rb
    # config[:SSLPrivateKey]
    # config[:SSLCertificate]
    # config[:SSLClientCA]
    # config[:SSLExtraChainCert]
    # config[:SSLCACertificateFile]
    # config[:SSLCACertificatePath]
    # config[:SSLCertificateStore]
    # config[:SSLVerifyClient]
    # config[:SSLVerifyDepth]
    # config[:SSLVerifyCallback]
    # config[:SSLTimeout]
    # config[:SSLOptions]

    debugger

    # This may point to a single CA certificate or a bundle of CA certificates.
    # Only client certificates issued by the CA certificates listed in this
    # file will be considered valid by the server.
    results[:SSLCACertificateFile] = Puppet.settings[:ssl_server_ca_chain_auth]

    # SSLExtraChainCert should point to a bundle building trust to the
    # authorizing CA certs listed in the ssl_server_ca_chain_auth setting.
    # These certificates are not directly used for authentication, they're
    # indirectly used to build trust.
    # JJM - SSLExtraChainCert result expects an array of OpenSSL::X509::Certificate instances
    # results[:SSLExtraChainCert] = nil
    trust_chain_loader = Puppet::Util::X509CertLoader.new_from_file(Puppet.settings[:ssl_server_ca_chain_trust])
    x509_chain_certs = trust_chain_loader.certificates
    results[:SSLExtraChainCert] = x509_chain_certs

    # SSLClientCA - Additional CA certificates to send to the client connection
    # This expects a single or an array of OpenSSL::X509::Certificate instances
    # results[:SSLClientCA] = ssl_server_ca_chain_client.certificate.content
    client_chain_loader = Puppet::Util::X509CertLoader.new_from_file(Puppet.settings[:ssl_server_ca_chain_client])
    x509_client_certs = client_chain_loader.certificates
    results[:SSLClientCA] = x509_client_certs

    results[:SSLCertificateStore] = host.ssl_store

    results
  end
end
