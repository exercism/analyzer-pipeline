require 'test_helper'

class Pipeline::Rpc::Worker::WorkerActionTest < Minitest::Test

  def setup
    @credentials = {
      "access_key_id" => "ACCESS_KEY_ID",
      "secret_access_key" => "SECRET_KEY",
      "session_token" => "SESSION",
    }
    @request = {
      "context" => { "credentials" => @credentials },
      "track_slug" => "demo",
      "exercise_slug" => "my-exercise",
      "id" => "my-input-id",
      "container_version" => "abcdef"
    }
    @return_address = "_return_address"
    @environment = mock()
    @action = Pipeline::Rpc::Worker::ContainerAction.new(@request, @return_address)
    @action.environment = @environment
  end

  def test_prepare_folder_raises
    error = assert_raises do
      @action.prepare_folder("/tmp/my_folder")
    end
    assert_equal "Please prepare input", error.message
  end

  def test_setup_container_run
    error = assert_raises do
      @action.setup_container_run("/tmp/my_folder", "foo", "bar")
    end
    assert_equal "Please create run command", error.message
  end

  def test_s3_download
    working_folder = Dir.mktmpdir

    s3 = mock()
    mock_listing = stub(contents: [
      {
        key: "example_path/to/iteration_folder/basic_file.txt"
      },
      {
        key: "example_path/to/iteration_folder/inner/folder/another_file.txt"
      },
      {
        key: "example_path/to/iteration_folder/inner/folder/file_without_extension"
      },
    ])

    s3.expects(:list_objects).with(
      bucket: "example_bucket",
      prefix: "example_path/to/iteration_folder/"
    ).returns(mock_listing)

    s3.expects(:get_object).with(
      bucket: "example_bucket",
      key: "example_path/to/iteration_folder/basic_file.txt",
      response_target: "#{working_folder}/basic_file.txt"
    )

    s3.expects(:get_object).with(
      bucket: "example_bucket",
      key: "example_path/to/iteration_folder/inner/folder/another_file.txt",
      response_target: "#{working_folder}/inner/folder/another_file.txt"
    )

    s3.expects(:get_object).with(
      bucket: "example_bucket",
      key: "example_path/to/iteration_folder/inner/folder/file_without_extension",
      response_target: "#{working_folder}/inner/folder/file_without_extension"
    )

    @action.expects(:s3).returns(s3).at_least_once
    @action.s3_sync("s3://example_bucket/example_path/to/iteration_folder", working_folder)

    assert File.directory?("#{working_folder}")
    assert File.directory?("#{working_folder}/inner/folder")
  end

  def test_invoke_when_correct_container_is_not_released
    @environment.expects(:released?).with("demo", "abcdef").returns(false)
    result = @action.invoke
    assert_equal 404, result[:status_code]
    assert_equal "Container demo:abcdef isn't available", result[:error]
    assert_equal :error_response, result[:msg_type]
  end

  def test_invoke_when_set_fails
    @environment.expects(:released?).with("demo", "abcdef").returns(true)
    @environment.expects(:track_dir).with("demo", "abcdef").returns("/tmp/foobar")

    @action.expects(:setup_container_run).raises("Ouch! Couldn't setup job")

    result = @action.invoke
    assert_equal 500, result[:status_code]
    assert_equal "Failure setting up job", result[:error]
    assert_equal :error_response, result[:msg_type]
  end

  def test_invoke_when_prepare_iteration_fails
    @environment.expects(:released?).with("demo", "abcdef").returns(true)
    @environment.expects(:track_dir).with("demo", "abcdef").returns("/tmp/foobar")

    @stub_job_invoker = mock()
    @stub_job_invoker.expects(:prepare_iteration).raises("Ouch! Couldn't prepare input")
    @stub_job_invoker.expects(:analyze!).never

    @action.expects(:setup_container_run).with("/tmp/foobar", "my-exercise", "my-input-id").returns @stub_job_invoker

    result = @action.invoke
    assert_equal 500, result[:status_code]
    assert_equal "Failure preparing input", result[:error]
    assert_equal :error_response, result[:msg_type]
  end

  def test_invoke_when_container_errors
    @environment.expects(:released?).with("demo", "abcdef").returns(true)
    @environment.expects(:track_dir).with("demo", "abcdef").returns("/tmp/foobar")

    @stub_job_invoker = mock()
    @stub_job_invoker.expects(:prepare_iteration)
    @stub_job_invoker.expects(:analyze!).raises("Container error")

    @action.expects(:setup_container_run).with("/tmp/foobar", "my-exercise", "my-input-id").returns @stub_job_invoker

    result = @action.invoke
    assert_equal 500, result[:status_code]
    assert_equal "Error from container", result[:error]
    assert_equal :error_response, result[:msg_type]
  end

  def test_invoke
    @invocation_result = { a: 1, b: 2, exit_status: 0 }

    @environment.expects(:released?).with("demo", "abcdef").returns(true)
    @environment.expects(:track_dir).with("demo", "abcdef").returns("/tmp/foobar")

    @stub_job_invoker = mock()
    @stub_job_invoker.expects(:prepare_iteration)
    @stub_job_invoker.expects(:analyze!).returns(@invocation_result)

    @action.expects(:setup_container_run).with("/tmp/foobar", "my-exercise", "my-input-id").returns @stub_job_invoker

    result = @action.invoke
    assert_equal 1, result[:a]
    assert_equal 2, result[:b]
    assert_equal 0, result[:exit_status]
    assert_equal :response, result[:msg_type]
  end

end
