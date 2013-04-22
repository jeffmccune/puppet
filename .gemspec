# -*- encoding: utf-8 -*-
#
# This gemspec is not intended to be used for building the Puppet gem.  This
# gemspec is intended for use with bundler when Puppet is a dependency of
# another project.  For example, the stdlib project is able to integrate with
# the master branch of Puppet by using a Gemfile path of
# git://github.com/puppetlabs/puppet.git
#
# Please see the [packaging
# repository](https://github.com/puppetlabs/packaging) for information on how
# to build the Puppet gem package.

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))
require 'puppet/version'

Gem::Specification.new do |s|
  s.name = "puppet"
  version = Puppet.version
  if mdata = version.match(/(\d+\.\d+\.\d+)/)
    s.version = mdata[1]
  else
    s.version = version
  end

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Puppet Labs"]
  s.date = "2012-08-17"
  s.description = "Puppet, an automated configuration management tool"
  s.email = "puppet@puppetlabs.com"
  s.executables = ["puppet"]
  s.files = ["bin/puppet"]
  s.homepage = "http://puppetlabs.com"
  s.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "puppet"
  s.rubygems_version = "1.8.24"
  s.summary = "Puppet, an automated configuration management tool"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<facter>, ["~> 1.5"])
    else
      s.add_dependency(%q<facter>, ["~> 1.5"])
    end
  else
    s.add_dependency(%q<facter>, ["~> 1.5"])
  end
end
