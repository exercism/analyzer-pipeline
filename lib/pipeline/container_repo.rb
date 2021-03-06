class Pipeline::ContainerRepo

  def self.instance_for(container_slug, credentials)
    Pipeline::ContainerRepo.new(container_slug, credentials)
  end

  attr_reader :image_name

  def initialize(image_name, credentials=nil)
    @image_name = image_name
    @credentials = credentials
  end

  def create_if_required
    puts "Checking if repository exists"
    begin
      return lookup_repo
    rescue Aws::ECR::Errors::RepositoryNotFoundException
      puts "Repository #{image_name} not found"
    end
    puts "Creating repository"
    ecr.create_repository({
      repository_name: image_name,
      image_tag_mutability: "MUTABLE"
    })
    lookup_repo
  end

  def lookup_repo
    repos = ecr.describe_repositories({
      repository_names: [image_name]
    })
    repos.repositories.first
  end

  def repository_url
    lookup_repo.repository_uri
  end

  def create_login_token
    authorization_token = ecr.get_authorization_token.authorization_data[0].authorization_token
    plain = Base64.decode64(authorization_token)
    user,password = plain.split(":")
  end

  def list_images
    puts "credentials #{@credentials}"
    puts "ECR #{ecr}"
    puts create_login_token
    ecr.list_images({
      repository_name: image_name
    })
  end


  def images_info
    images = list_images()
    info = {}
    images.image_ids.each do |image|
      info[image.image_digest] ||= []
      info[image.image_digest] << image.image_tag
    end
    info
  end

  def git_shas
    images = list_images()
    tags = []
    images.image_ids.each do |image|
      tag = image.image_tag
      next if tag.nil?
      # Only return git-based shas
      if tag.start_with?("git-")
        tag = tag.gsub(/git-/, "")
        tags << tag unless tag.include?("-")
      end
    end
    tags.uniq
  end

  def ecr
    @ecr ||= begin
      ( @credentials.nil? ) ?
        Aws::ECR::Client.new(region: 'eu-west-1') :
        Aws::ECR::Client.new(region: 'eu-west-1', credentials: @credentials)
    end
  end

end
