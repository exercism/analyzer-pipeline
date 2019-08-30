ENV["env"] = "test"
gem "minitest"

require 'simplecov'
SimpleCov.start

require "minitest/autorun"
require "minitest/pride"
require "minitest/mock"
require "mocha/setup"

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pipeline"
