class Pipeline::AnalyzerBuild
  include Mandate

  attr_accessor :img

  initialize_with :track_slug

  def call
    @img = File.expand_path "./opt/img"
    repo.fetch!
    checkout
    build
    puts "login"
    login_to_repository
    tag_build
    push_build
    logout
  end



  def checkout
    repo.checkout("master")
  end

  def build
    opt_dir = File.expand_path "./opt"
    Dir.chdir(repo.workdir) do
      cmd = "#{build_cmd} -t #{current_tag} ."
      exec_cmd cmd
    end
  end

  def login_to_repository
    ecr = Aws::ECR::Client.new(region: 'eu-west-1')
    authorization_token = ecr.get_authorization_token.authorization_data[0].authorization_token
    plain = Base64.decode64(authorization_token)
    user,password = plain.split(":")
    exec_cmd "#{img} login -u AWS -p \"#{password}\" #{registry_endpoint}"
  end

  def logout
    exec_cmd "#{img} logout #{registry_endpoint}"
  end

  def tag_build
    # exec_cmd "#{img} tag #{current_tag} #{registry_endpoint}/#{current_tag}"
    # exec_cmd "#{img} tag #{current_tag} #{registry_endpoint}/#{slug}:latest"
  end

  def push_build
    exec_cmd "#{push_cmd} #{current_tag}"
    # exec_cmd "#{img} push #{registry_endpoint}/#{slug}:latest"
  end

  def push_cmd
    "#{img} push -state /tmp/state-img"
  end

  def build_cmd
    "#{img} build -state /tmp/state-img"
  end

  def exec_cmd(cmd)
    puts "> #{cmd}"
    puts "------------------------------------------------------------"
    success = system({}, cmd)
    raise "Failed #{cmd}" unless success
  end

  def current_tag
    "#{registry_endpoint}/#{slug}:abc"
  end

  def registry_endpoint
    "681735686245.dkr.ecr.eu-west-1.amazonaws.com"
  end

  def slug
    "#{track_slug}-analyzer-dev"
  end

  memoize
  def repo
    repo_url = "https://github.com/exercism/#{track_slug}-analyzer"
    Pipeline::AnalyzerRepo.new(repo_url)
  end
end
