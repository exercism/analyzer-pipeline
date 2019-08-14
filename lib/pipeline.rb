require "mandate"
require "propono"
require "active_support"
require 'securerandom'
require 'rugged'
require 'aws-sdk-ecr'

Aws.config.update({
   credentials: Aws::Credentials.new('AKIAZ5OU5BBSQDMMFQ7J', '+Q2fMSju+dJljn6G2XFZOt6vUHgSF56P736yPQhj')
})

module Pipeline
  def self.spike
    puts "OK"
    # AnalyzerBuild.("ruby")
    repo = Pipeline::AnalyzerRepo.new("/home/ccare/code/exercism/sample-analyzer")
    repo.fetch!
    puts "DONE"
  end
end

require "pipeline/analyzer_repo"
require "pipeline/analyzer_build"
require "pipeline/validate_build"
require "pipeline/util/runc_configurator"
require "pipeline/util/img_wrapper"
require "pipeline/build_image"
