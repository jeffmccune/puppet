
module Puppet::Util::ReferenceSerializer
  def unserialize_value(val)
    case val
    when /^--- /
      begin
        YAML.load(val)
      rescue Exception => detail
        if detail.to_s.match(/allocator/i)
          # JJM FIXME Debug output for puppet-users thread http://goo.gl/a7cqA
          # This requires a JSON library, available with `gem install multi_json`
          file = "/tmp/for_jeff.json"
          if not File.exists?(file)
            Puppet.debug "Wrote val to #{file}"
            File.open(file, "w+") { |f| f.puts(PSON.dump(val)) }
          end
        end
      end
    when "true"
      true
    when "false"
      false
    else
      val
    end
  end

  def serialize_value(val)
    case val
    when Puppet::Resource
      YAML.dump(val)
    when true, false
      # The database does this for us, but I prefer the
      # methods be their exact inverses.
      # Note that this means quoted booleans get returned
      # as actual booleans, but there doesn't appear to be
      # a way to fix that while keeping the ability to
      # search for parameters set to true.
      val.to_s
    else
      val
    end
  end
end
