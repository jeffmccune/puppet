# Jeff McCune <jeff@puppetlabs.com>
# 2011-04-11
#
# This is testing out the node_name_fact configuration option.
# To test, set a fact containing the node name information:
#
# export FACTER_mynodename="abc123"
# puppet apply --node_name=facter --node_name_fact=mynodename site.pp


$node_vars = "hostname=${hostname} fqdn=${fqdn} mynodename=${mynodename}"

node default {
  notify { "DEFAULT NODE":
    message => "DEFAULT NODE.  ${node_vars}",
  }
}

node abc123 {
  notify { "abc123 NODE":
    message => "abc123 NODE.  ${node_vars}",
  }
}

