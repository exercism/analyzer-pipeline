gem "minitest"

require "minitest/autorun"
require "minitest/pride"
require "minitest/mock"
require "mocha/setup"


$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pipeline_client"

module Pipeline
  class IntegrationTest < Minitest::Test

    attr_reader :client

    def setup
      @client = PipelineClient.new
    end

    def test_restart_workers
      resp = client.restart_workers!
      assert_equals true, clietn
    end

  end
end
