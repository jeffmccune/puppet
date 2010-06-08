#!/usr/bin/env ruby1.8

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/node/rest'

describe Puppet::Node::Rest do
    before do
        @searcher = Puppet::Node::Rest.new
    end


end
