require "mandate"
require "propono"
require "active_support"
require 'securerandom'
require 'rugged'
require 'aws-sdk-ecr'
require 'yaml'

module Pipeline

  def self.load_config(config_path)
    config = YAML.load(File.read(config_path))
    Aws.config.update({
       credentials: Aws::Credentials.new(config["aws_access_key_id"], config["aws_secret_access_key"])
    })
    @config = config
  end

  def self.config
    @config
  end

  def self.build_analyzer(track_slug)
    AnalyzerBuild.("master", track_slug)
  end

  def self.scratch
    track_slug = "rust"
    repo_url = "https://github.com/exercism/#{track_slug}-analyzer"
    repo = Pipeline::AnalyzerRepo.new(repo_url)
    puts repo.tags
  end
end

require "pipeline/analyzer_repo"
require "pipeline/analyzer_build"
require "pipeline/validation/check_invokable"
require "pipeline/validation/check_environment_invariants"
require "pipeline/validation/check_fixtures"
require "pipeline/validation/fixture_check_error.rb"
require "pipeline/validate_build"
require "pipeline/util/container_driver"
require "pipeline/util/runc_configurator"
require "pipeline/util/img_wrapper"
require "pipeline/util/runc_wrapper"
require "pipeline/build_image"
require "pipeline/publish_image"
