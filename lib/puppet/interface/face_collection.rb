require 'puppet/interface'

module Puppet::Interface::FaceCollection
  @faces = Hash.new { |hash, key| hash[key] = {} }

  def self.faces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        Dir.glob("#{dir}/puppet/face/*.rb").
          collect {|f| File.basename(f, '.rb') }.
          each {|name| self[name, :current] }
      end
    end
    @faces.keys.select {|name| @faces[name].length > 0 }
  end

  def self.[](name, version)
    name = underscorize(name)
    get_face(name, version) or load_face(name, version)
  end

  def self.get_action_for_face(name, action_name, version)
    name = underscorize(name)

    # If the version they request specifically doesn't exist, don't search
    # elsewhere.  Usually this will start from :current and all...
    return nil unless face = self[name, version]
    unless action = face.get_action(action_name)
      # ...we need to search for it bound to an o{lder,ther} version.  Since
      # we load all actions when the face is first references, this will be in
      # memory in the known set of versions of the face.
      (@faces[name].keys - [ :current ]).sort.reverse.each do |version|
        break if action = @faces[name][version].get_action(action_name)
      end
    end

    return action
  end

  # get face from memory, without loading.
  def self.get_face(name, pattern)
    return nil unless @faces.has_key? name
    return @faces[name][:current] if pattern == :current

    versions = @faces[name].keys - [ :current ]
    found    = SemVer.find_matching(pattern, versions)
    return @faces[name][found]
  end

  # try to load the face, and return it.
  def self.load_face(name, version)
    # We always load the current version file; the common case is that we have
    # the expected version and any compatibility versions in the same file,
    # the default.  Which means that this is almost always the case.
    #
    # We use require to avoid executing the code multiple times, like any
    # other Ruby library that we might want to use.  --daniel 2011-04-06
    if safely_require name then
      # If we wanted :current, we need to index to find that; direct version
      # requests just work™ as they go. --daniel 2011-04-06
      if version == :current then
        # We need to find current out of this.  This is the largest version
        # number that doesn't have a dedicated on-disk file present; those
        # represent "experimental" versions of faces, which we don't fully
        # support yet.
        #
        # We walk the versions from highest to lowest and take the first version
        # that is not defined in an explicitly versioned file on disk as the
        # current version.
        #
        # This constrains us to only ship experimental versions with *one*
        # version in the file, not multiple, but given you can't reliably load
        # them except by side-effect when you ignore that rule this seems safe
        # enough...
        #
        # Given those constraints, and that we are not going to ship a versioned
        # interface that is not :current in this release, we are going to leave
        # these thoughts in place, and just punt on the actual versioning.
        #
        # When we upgrade the core to support multiple versions we can solve the
        # problems then; as lazy as possible.
        #
        # We do support multiple versions in the same file, though, so we sort
        # versions here and return the last item in that set.
        #
        # --daniel 2011-04-06
        latest_ver = @faces[name].keys.sort.last
        @faces[name][:current] = @faces[name][latest_ver]
      end
    end

    unless version == :current or get_face(name, version)
      # Try an obsolete version of the face, if needed, to see if that helps?
      safely_require name, version
    end

    return get_face(name, version)
  end


  def self.autoloader
    @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/face")
  end


  def self.safely_require(name, version = nil)
    path = version ? File.join(version.to_s, name.to_s) : name.to_s
    return true if autoloader.loaded?(path)
    begin
      return true if autoloader.load(path)
    rescue Puppet::Error => e
      raise e unless e.message =~ /Could not autoload/
      Puppet.err "Failed to load face #{name}:\n"
      # ...but we just carry on after complaining.
      nil
    end
  end

  def self.register(face)
    @faces[underscorize(face.name)][face.version] = face
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z][-_a-z0-9]*$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid face name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end
end
