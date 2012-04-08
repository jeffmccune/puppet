require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:msi, :parent => Puppet::Provider::Package) do
  desc "Windows package management by installing and removing MSIs.

    This provider requires a `source` attribute, and will accept paths to local
    files, mapped drives, UNC paths, or URLs."

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  has_feature :installable
  has_feature :uninstallable
  has_feature :install_options

  # From msi.h
  INSTALLSTATE_ABSENT       =  2  # uninstalled (or action state absent but clients remain)
  INSTALLSTATE_DEFAULT      =  5  # use default, local or source

  INSTALLLEVEL_DEFAULT = 0      # install authored default

  INSTALLUILEVEL_NONE     = 2    # completely silent installation

  def self.pkglist
    list = []

    inst = installer
    inst.Products.each do |guid|
      # ignore advertised
      next unless inst.ProductState(guid) == INSTALLSTATE_DEFAULT

      hash = {}
      hash[:productcode] = guid
      {
        :name => 'ProductName',
        :version => 'VersionString',
        :language => 'Language',
        :packagecode => 'PackageCode',
        :installdate => 'InstallDate',
        :installlocation => 'InstallLocation',
        :publisher => 'Publisher',
        :transforms => 'Transforms'
      }.each_pair do |k,v|
        hash[k] = inst.ProductInfo(guid, v)
      end

      if source = inst.ProductInfo(guid, 'InstallSource') and
         package = inst.ProductInfo(guid, 'PackageName')
        hash[:source] = File.join(source, package)
      end

      hash[:provider] = self.name
      hash[:ensure] = hash[:version]

      list << hash
    end

    list
  end

  def self.instances
    pkglist.collect do |hash|
      new(hash)
    end
  end

  def query
    if hash = self.class.pkglist.find { |hash| hash[:name].casecmp(resource[:name]) == 0 }
      hash
    else
      {:ensure => :absent}
    end
  end

  def install
    # properties is a string delimited by spaces, so each key value must be quoted
    properties_for_command = ""
    if resource[:install_options]
      properties_for_command = resource[:install_options].collect do |k,v|
        property = shell_quote k
        value    = shell_quote v

        "#{property}=#{value}"
      end
    end

    self.class.installer.InstallProduct(resource[:source], "ACTION=INSTALL #{properties_for_command}")
  end

  def uninstall
    self.class.installer.ConfigureProduct(resource.provider.properties[:productcode], INSTALLLEVEL_DEFAULT, INSTALLSTATE_ABSENT)
  end

  def validate_source(value)
    fail("The source parameter cannot be empty when using the MSI provider.") if value.empty?
  end

  private

  def self.installer
    require 'win32ole'
    installer = WIN32OLE.new("WindowsInstaller.Installer")
    installer.UILevel = INSTALLUILEVEL_NONE
    installer
  end

  def shell_quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end

# These are other MSI product properties that are available, but not sure
# they provide any information.

      # INSTALLPROPERTY_HELPLINK       HelpLink=
      # INSTALLPROPERTY_HELPTELEPHONE  HelpTelephone=
      # INSTALLPROPERTY_LOCALPACKAGE   LocalPackage=C:\WINDOWS\Installer\1afa8.msi
      # INSTALLPROPERTY_URLINFOABOUT   URLInfoAbout=http://www.vmware.com
      # INSTALLPROPERTY_URLUPDATEINFO  URLUpdateInfo=
      # INSTALLPROPERTY_VERSIONMINOR
      # INSTALLPROPERTY_VERSIONMAJOR
      #AssignmentType=1
      #InstanceType=0
      #ProductID=none
      #ProductIcon=C:\WINDOWS\Installer\{FE2F6A2C-196E-4210-9C04-2B1BC21F07EF}\ARPPRODUCTICON.exe
      #RegCompany=
      #RegOwner=josh
