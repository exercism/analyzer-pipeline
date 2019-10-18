require 'test_helper'
require 'json'

class Pipeline::Rpc::Worker::WorkerActionTest < Minitest::Test

  def setup
    @action = Pipeline::Rpc::Worker::WorkerAction.new
  end

  def test_invoke_does_nothing
    @action.invoke
  end

  def test_parse_credentials
    @credentials = {
      "access_key_id" => "ACCESS_KEY_ID",
      "secret_access_key" => "SECRET_KEY",
      "session_token" => "SESSION",
    }
    @request = {
      "credentials" => @credentials
    }
    credentials = @action.parse_credentials(@request)

    assert_equal Aws::Credentials, credentials.class
    assert_equal "ACCESS_KEY_ID", credentials.access_key_id
    assert_equal "SECRET_KEY", credentials.secret_access_key
    assert_equal "SESSION", credentials.session_token
  end

end
