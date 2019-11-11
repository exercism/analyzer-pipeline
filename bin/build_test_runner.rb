#!/usr/bin/env ruby
require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "pipeline"

track_slug = ARGV[0]
project_suffix = "test-runner"

env_suffix = (ENV["env"] == "production") ? "" : "-dev"

puts "Building <#{project_suffix}> for <#{track_slug}> (#{env_suffix})"

repo = Pipeline::AnalyzerRepo.for_track(track_slug, project_suffix)
latest_tag = repo.tags.keys.last
if (latest_tag.nil?)
  latest_tag = "master"
end

config = YAML.load(File.read(File.expand_path('../../config/pipeline.yml', __FILE__)))
credentials = Aws::Credentials.new(config["aws_access_key_id"], config["aws_secret_access_key"])
container_repo = Pipeline::ContainerRepo.new("#{track_slug}-#{project_suffix}#{env_suffix}", credentials)

Pipeline::Build::TestRunnerBuild.(latest_tag, track_slug, repo, container_repo)
