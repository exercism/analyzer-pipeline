require "mandate"
require "propono"
require "active_support"
require 'securerandom'
require 'rugged'
require 'aws-sdk-ecr'
require 'aws-sdk-s3'
require 'aws-sdk-sts'
require 'yaml'
require 'json'
require 'ffi-rzmq'
require 'rb-inotifyq'

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module Pipeline

  # def self.load_config(config_path)
  #   config = YAML.load(File.read(config_path))
  #   Aws.config.update({
  #      credentials: Aws::Credentials.new(config["aws_access_key_id"], config["aws_secret_access_key"])
  #   })
  #   @config = config
  # end

  def self.config
    @config
  end

#   def self.release(language_slug)
#     puts "Releasing #{language_slug}"
#     env_base = "/tmp/analyzer-env/#{SecureRandom.hex}"
#     env_base = "/tmp/analyzer-env/1e9c733fd7502974c2a3fdd85da9c844"
#     environment = Runtime::RuntimeEnvironment.new(env_base)
#     environment.prepare
#     environment.release_analyzer(language_slug)
#   end
#
#   def self.analyze!(language_slug, exercise_slug, solution_slug)
#     env_base = "/tmp/analyzer-env/1e9c733fd7502974c2a3fdd85da9c844"
#     environment = Runtime::RuntimeEnvironment.new(env_base)
#     analysis_run = environment.new_analysis(language_slug, exercise_slug, solution_slug)
#     analysis_run.prepare_iteration do |iteration_folder|
#       yield(iteration_folder)
#     end
#     begin
#       analysis_run.analyze!
#     rescue => e
#       puts e
#     ensure
#       # puts "---"
#       # puts analysis_run.stdout
#       # puts "==="
#       # puts analysis_run.stderr
#       # puts "---"
#       # puts analysis_run.success?
#       # puts analysis_run.exit_status
#       # puts analysis_run.result
#       puts "DONE"
#     end
#   end
end

# require "pipeline/rpc/router"
# require "pipeline/rpc/worker"
# require "pipeline/analyzer_repo"
# require "pipeline/container_repo"
# require "pipeline/validation/check_invokable"
# require "pipeline/validation/check_environment_invariants"
# require "pipeline/validation/check_fixtures"
# require "pipeline/validation/fixture_check_error.rb"
# require "pipeline/validation/validate_build"
# require "pipeline/util/container_driver"
# require "pipeline/util/runc_configurator"
# require "pipeline/util/img_wrapper"
# require "pipeline/util/runc_wrapper"
# require "pipeline/util/external_command"
# require "pipeline/util/log_collector"
# require "pipeline/build/build_image"
# require "pipeline/build/publish_image"
# require "pipeline/build/container_build"
# require "pipeline/build/analyzer_build"
# require "pipeline/build/test_runner_build"
# require "pipeline/runtime/runtime_environment"
# require "pipeline/runtime/analysis_run"
