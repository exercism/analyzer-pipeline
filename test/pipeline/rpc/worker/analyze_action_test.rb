require 'test_helper'

class Pipeline::Rpc::Worker::AnalyzeActionTest < Minitest::Test

  def setup
    @request = {
      "track_slug" => "demo",
      "exercise_slug" => "my-exercise",
      "id" => "my-input-id",
      "s3_uri" => "s3://example_bucket/example_path/to/iteration_folder",
      "container_version" => "abcdef"
    }
    @action = Pipeline::Rpc::Worker::AnalyzeAction.new(@request, "abc")
  end

  def test_prepare_test_folder_downloads_all_files_and_creates_inner_folders
    @action.expects(:s3_sync).with("s3://example_bucket/example_path/to/iteration_folder", "/scratch/folder/1")
    @action.prepare_folder("/scratch/folder/1")
  end

end
