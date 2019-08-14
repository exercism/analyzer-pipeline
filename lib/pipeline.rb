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
    AnalyzerBuild.("ruby")
    puts "DONE"
  end
end

require "pipeline/analyzer_repo"
require "pipeline/analyzer_build"
require "pipeline/validate_build"
