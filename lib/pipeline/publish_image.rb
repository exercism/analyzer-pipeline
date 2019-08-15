class Pipeline::PublishImage
  include Mandate

  initialize_with :img, :image_name, :image_tag, :build_tag

  def call
    puts "PUBLISHING #{image_tag}"
    puts "Login to repo"
    login_to_repository
    tag_build
    push_build
    logout
  end

  def login_to_repository
    ecr = Aws::ECR::Client.new(region: 'eu-west-1')
    authorization_token = ecr.get_authorization_token.authorization_data[0].authorization_token
    plain = Base64.decode64(authorization_token)
    user,password = plain.split(":")
    img.login("AWS", password, registry_endpoint)
  end

  def logout
    img.logout(registry_endpoint)
  end

  def tag_build
    img.tag(image_tag, remote_tag)
    img.tag(image_tag, remote_human_tag) unless build_tag.nil?
    img.tag(image_tag, remote_latest_tag)
  end

  def push_build
    img.push(remote_tag)
    img.push(remote_human_tag) unless build_tag.nil?
    img.push(remote_latest_tag)
  end

  def remote_tag
    "#{registry_endpoint}/#{image_tag}"
  end

  def remote_human_tag
    "#{registry_endpoint}/#{image_name}:#{build_tag}"
  end

  def remote_latest_tag
    "#{registry_endpoint}/#{image_name}:latest"
  end

  def registry_endpoint
    Pipeline.config["registry_endpoint"]
  end

end
