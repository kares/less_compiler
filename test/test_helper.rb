require 'rubygems'
require 'test/unit'
require 'active_support'
require 'active_support/test_case'

require 'active_support/version'
puts "using active_support version = #{ActiveSupport::VERSION::STRING}"

$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require 'less_compiler'

#require File.join(File.dirname(__FILE__), '../lib/less_compiler')
