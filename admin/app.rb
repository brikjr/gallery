require 'sinatra/base'
require 'octokit'
require 'json'
require 'securerandom'
require 'yaml'
require 'fileutils'
require 'mini_magick'
require 'bcrypt'
require 'base64'
require 'tempfile'
require 'open3'
require 'dotenv'
require 'logger'

# Load environment variables before defining the class
Dotenv.load('.env.local', '.env') if ENV['RACK_ENV'] != 'production'

# Add near the top, after requires
puts "Current environment: #{ENV['RACK_ENV']}"
puts "Loaded environment variables:"
puts "ADMIN_USERNAME: #{ENV['ADMIN_USERNAME'] ? 'set' : 'not set'}"
puts "ADMIN_PASSWORD: #{ENV['ADMIN_PASSWORD'] ? 'set' : 'not set'}"
puts "SESSION_SECRET: #{ENV['SESSION_SECRET'] ? 'set' : 'not set'}"
puts "GITHUB_TOKEN: #{ENV['GITHUB_TOKEN'] ? 'set' : 'not set'}"
puts "REPO_NAME: #{ENV['REPO_NAME'] ? 'set' : 'not set'}"

class AdminPanel < Sinatra::Base
  # Debug output before configure block
  puts "Current environment: #{ENV['RACK_ENV']}"
  puts "Loaded environment variables:"
  puts "ADMIN_USERNAME: #{ENV['ADMIN_USERNAME'] ? 'set' : 'not set'}"
  puts "ADMIN_PASSWORD: #{ENV['ADMIN_PASSWORD'] ? 'set' : 'not set'}"
  puts "SESSION_SECRET: #{ENV['SESSION_SECRET'] ? 'set' : 'not set'}"
  puts "GITHUB_TOKEN: #{ENV['GITHUB_TOKEN'] ? 'set' : 'not set'}"
  puts "REPO_NAME: #{ENV['REPO_NAME'] ? 'set' : 'not set'}"

  configure do
    enable :logging
    
    # Set up logger
    set :logger, Logger.new(STDOUT)
    settings.logger.level = Logger::DEBUG

    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, 'views')
    set :public_folder, File.join(settings.root, 'public')
    enable :sessions
    set :session_secret, ENV['SESSION_SECRET']
    set :protection, true
    enable :dump_errors if development?
    
    # Add local repository path
    set :repo_path, ENV['LOCAL_REPO_PATH'] || File.expand_path('../..', __FILE__)
  end

  # Debug output
  puts "Current environment: #{ENV['RACK_ENV']}"
  puts "Loaded environment variables:"
  puts "ADMIN_USERNAME: #{ENV['ADMIN_USERNAME'] ? 'set' : 'not set'}"
  puts "ADMIN_PASSWORD: #{ENV['ADMIN_PASSWORD'] ? 'set' : 'not set'}"
  puts "SESSION_SECRET: #{ENV['SESSION_SECRET'] ? 'set' : 'not set'}"
  puts "GITHUB_TOKEN: #{ENV['GITHUB_TOKEN'] ? 'set' : 'not set'}"
  puts "REPO_NAME: #{ENV['REPO_NAME'] ? 'set' : 'not set'}"

  # Constants - define only once
  GITHUB_TOKEN = ENV['GITHUB_TOKEN']
  REPO_NAME = ENV['REPO_NAME']
  BRANCH = 'main'

  # Add helper to check if environment variables are set
  def check_env_vars
    required_vars = %w[ADMIN_USERNAME ADMIN_PASSWORD SESSION_SECRET GITHUB_TOKEN REPO_NAME]
    missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
    
    unless missing_vars.empty?
      logger.error "Missing required environment variables: #{missing_vars.join(', ')}"
      halt 500, "Server configuration error. Check logs for details."
    end
  end

  # Add before filter to check environment variables
  before do
    check_env_vars
  end

  ADMIN_USERNAME = ENV['ADMIN_USERNAME'] || 'admin'
  # Create password hash during initialization
  ADMIN_PASSWORD = begin
    stored_hash = ENV['ADMIN_PASSWORD']
    if stored_hash
      # Use stored hash from environment
      stored_hash
    else
      # Create new hash for default password
      BCrypt::Password.create('password123')
    end
  end

  # Add a helper method to verify password
  def verify_password(input_password)
    begin
      BCrypt::Password.new(ADMIN_PASSWORD) == input_password
    rescue BCrypt::Errors::InvalidHash
      false
    end
  end

  def github_client
    @github_client ||= begin
      client = Octokit::Client.new(access_token: GITHUB_TOKEN)
      
      # Check if branch exists, create if it doesn't
      begin
        client.branch(REPO_NAME, BRANCH)
      rescue Octokit::NotFound
        # Get default branch
        repo = client.repository(REPO_NAME)
        default_branch = repo.default_branch
        
        # Get reference to default branch
        ref = client.ref(REPO_NAME, "heads/#{default_branch}")
        
        # Create new branch from default branch
        client.create_ref(
          REPO_NAME,
          "refs/heads/#{BRANCH}",
          ref.object.sha
        )
        
        logger.info "Created new branch: #{BRANCH}"
      end
      
      client
    end
  end

  # Add before filter for all routes
  before do
    # Generate CSRF token if not present
    session[:csrf] ||= SecureRandom.base64(32)
    
    # Debug logging
    logger.info "Request: #{request.path_info}"
    logger.info "Session: #{session.inspect}"
    logger.info "Authenticated: #{authenticated?}"
  end

  helpers do
    def authenticate!
      unless authenticated?
        session[:return_to] = request.path
        redirect '/admin/login'
      end
    end

    def authenticated?
      session[:authenticated] == true
    end

    def verify_credentials(username, password)
      return false if username.nil? || password.nil?
      return false unless username == ENV['ADMIN_USERNAME']
      
      begin
        stored_hash = ENV['ADMIN_PASSWORD'].to_s
                       .strip
                       .gsub(/\\/, '')  # Remove escape characters
                       .gsub(/["']/, '') # Remove quotes
        
        settings.logger.debug "Raw stored hash from ENV: #{ENV['ADMIN_PASSWORD'].inspect}"
        settings.logger.debug "Processed hash: #{stored_hash.inspect}"
        settings.logger.debug "Input password: #{password.inspect}"
        
        # Verify the hash format
        unless stored_hash.start_with?('$2a$')
          settings.logger.error "Invalid hash format in ENV"
          return false
        end
        
        bcrypt_password = BCrypt::Password.new(stored_hash)
        result = bcrypt_password == password
        settings.logger.debug "Password verification result: #{result}"
        result
      rescue BCrypt::Errors::InvalidHash => e
        settings.logger.error "Invalid password hash: #{e.message}"
        settings.logger.error "Hash value: #{stored_hash.inspect}"
        false
      rescue => e
        settings.logger.error "Password verification error: #{e.class} - #{e.message}"
        settings.logger.error e.backtrace.join("\n")
        false
      end
    end
    
    def normalize_gallery_name(name)
      # Convert 'landscapes' to 'landscape' in URLs
      name == 'landscapes' ? 'landscape' : name
    end
    
    def get_galleries
      # Get list of directories from GitHub
      contents = github_client.contents(REPO_NAME, path: 'images', ref: BRANCH)
      # Filter out 'slider' and get only gallery directories
      galleries = contents.select { |c| c.type == 'dir' && c.name != 'slider' }.map(&:name)
      # Normalize 'landscapes' to 'landscape' in the list
      galleries.map { |g| g == 'landscapes' ? 'landscape' : g }
    end
    
    def get_gallery_images(gallery)
      begin
        # Get all files in the gallery directory
        contents = github_client.contents(REPO_NAME, path: "images/albums/#{gallery}")
        
        # Filter out thumbnails directory and get only images
        images = contents.select do |file| 
          file.type == 'file' && 
          !file.path.include?('/thumbs/') && 
          file.name =~ /\.(jpg|jpeg|png|gif)$/i
        end

        # Get gallery metadata if it exists
        metadata = begin
          # Special case for landscape -> landscapes
          index_path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
          
          index_content = github_client.contents(REPO_NAME, 
            path: index_path,
            ref: BRANCH)
          
          file_content = Base64.decode64(index_content.content)
          front_matter = file_content.split('---')[1]
          
          if front_matter
            yaml_data = YAML.load(front_matter)
            yaml_data['images'] if yaml_data
          end
        rescue Octokit::NotFound
          logger.error "Gallery index not found for #{gallery}"
          nil
        rescue => e
          logger.error "Error parsing gallery metadata: #{e.message}"
          nil
        end || []

        # Map images to include metadata
        images.map do |file|
          image_data = metadata.find { |m| m['image_path'].end_with?(file.name) }
          {
            'name' => file.name,
            'path' => file.path,
            'url' => file.download_url,
            'caption' => image_data&.fetch('caption', file.name),
            'copyright' => image_data&.fetch('copyright', '© Your Name')
          }
        end
      rescue Octokit::NotFound => e
        logger.error "Gallery not found: #{e.message}"
        []
      rescue => e
        logger.error "Unexpected error: #{e.message}"
        []
      end
    end

    def commit_file(gallery, file, filename)
      path = "images/albums/#{gallery}/#{filename}"
      
      # Read and encode file content
      file.rewind
      content = Base64.strict_encode64(file.read)
      
      begin
        # Try to get existing file first
        existing_file = github_client.contents(REPO_NAME, path: path)
        
        # Update existing file
        github_client.update_contents(
          REPO_NAME,
          path,
          "Update #{filename}",
          existing_file.sha,
          content,
          branch: BRANCH
        )
      rescue Octokit::NotFound
        # Create new file if it doesn't exist
        github_client.create_contents(
          REPO_NAME,
          path,
          "Add #{filename}",
          content,
          branch: BRANCH
        )
      end

      # Update gallery index
      update_gallery_yaml(gallery, filename)
    end

    def update_gallery_yaml(gallery, filename)
      path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
      
      begin
        # Get current file
        file = github_client.contents(REPO_NAME, path: path)
        content = Base64.decode64(file.content)
        
        # Keep the original front matter intact
        parts = content.split(/^---\s*$/)
        front_matter = parts[1] || ""
        rest_content = parts[2] || "\n"
        
        # Format new image entry exactly like Python script
        new_image_entry = [
          " - image_path: /images/albums/#{gallery}/#{filename}",
          "   caption: #{params[:caption].to_s.strip.empty? ? filename : params[:caption].strip}",
          "   copyright: #{params[:copyright] ? "© #{params[:copyright].strip}" : default_copyright}"
        ].join("\n")
        
        if content.include?('images:')
          # Find where the images section ends
          images_end = content.index(/^[a-zA-Z].*:.*$/, content.index('images:')) || content.index('---', content.index('images:'))
          
          # Insert new image entry before the next section or closing ---
          updated_content = content.dup
          updated_content.insert(images_end - 1, "\n#{new_image_entry}\n")
        else
          # If no images section exists, create it
          front_matter = <<~YAML
            layout: page
            title: #{gallery.capitalize}
            description: #{gallery.capitalize} gallery
            active: gallery
            header-img: /images/albums/#{gallery}/header.jpg
            album-title: "🎞️"
            images:
            #{new_image_entry}
          YAML
          
          updated_content = ["---", front_matter.strip, "---", rest_content].join("\n")
        end
        
        # Update file in GitHub
        github_client.update_contents(
          REPO_NAME,
          path,
          "Update index.html with new image #{filename}",
          file.sha,
          updated_content,
          branch: BRANCH
        )
      rescue Octokit::NotFound
        # Create new file with basic structure
        front_matter = <<~YAML
          layout: page
          title: #{gallery.capitalize}
          description: #{gallery.capitalize} gallery
          active: gallery
          header-img: /images/albums/#{gallery}/header.jpg
          album-title: "🎞️"
          images:
          #{new_image_entry}
        YAML
        
        new_content = ["---", front_matter.strip, "---", "\n"].join("\n")
        
        github_client.create_contents(
          REPO_NAME,
          path,
          "Create index.html with new image #{filename}",
          new_content,
          branch: BRANCH
        )
      end
    end

    def flash
      session[:flash] ||= {}
    end
    
    def sync_with_local_repo(gallery, filename, file_content)
      # Ensure directories exist
      gallery_path = File.join(settings.repo_path, 'images', 'albums', gallery)
      thumb_path = File.join(gallery_path, 'thumbs')
      FileUtils.mkdir_p(gallery_path)
      FileUtils.mkdir_p(thumb_path)
      
      # Save original file
      File.open(File.join(gallery_path, filename), 'wb') do |f|
        f.write(file_content)
      end
      
      # Create and save thumbnail
      image = MiniMagick::Image.read(file_content)
      image.resize "400x400"
      File.open(File.join(thumb_path, filename), 'wb') do |f|
        f.write(image.to_blob)
      end
    end

    def clear_flash
      session.delete(:flash)
    end
    
    def default_copyright
      '© Brik'
    end

    def require_authentication
      redirect '/admin/login' unless authenticated?
    end
  end

  # Add before filter for protected routes
  before '/dashboard' do
    require_authentication
  end

  before '/gallery/*' do
    require_authentication
  end

  # Add error handling
  not_found do
    status 404
    "Page not found"
  end

  error do
    status 500
    "Something went wrong - " + env['sinatra.error'].message
  end

  # Move test route to the top
  get '/test' do
    content_type :text
    'Admin panel is working!'
  end

  get '/' do
    redirect '/admin/login'
  end

  # Login routes
  get '/login' do
    erb :login
  end

  post '/login' do
    # Add debug logging
    logger.info "Password attempt: #{params[:password]}"
    logger.info "Expected password: #{ENV['ADMIN_PASSWORD']}"
    
    if params[:password] == ENV['ADMIN_PASSWORD']
      session[:authenticated] = true
      redirect '/admin/dashboard'
    else
      @error = "Invalid password"
      erb :login
    end
  end

  # Add logout route
  get '/logout' do
    session.clear
    redirect '/admin/login'
  end

  # Dashboard
  get '/dashboard' do
    @galleries = get_galleries
    erb :dashboard
  end

  # Gallery management
  get '/gallery/:name' do
    @gallery = normalize_gallery_name(params[:name])
    @images = get_gallery_images(@gallery)
    
    # Store flash messages and clear them
    @flash_messages = session[:flash]
    clear_flash
    
    erb :gallery
  end

  # Image upload
  post '/gallery/:gallery/upload' do
    authenticate!
    
    gallery = params[:gallery]
    file = params[:file]
    filename = file[:filename]
    
    if process_image(gallery, file[:tempfile], filename)
      flash[:success] = "Image uploaded successfully"
    else
      flash[:error] = "Failed to upload image"
    end
    
    redirect "/admin/gallery/#{gallery}"
  end

  # Delete image
  post '/gallery/:name/delete/:image' do
    require_authentication
    gallery = normalize_gallery_name(params[:name])
    image = params[:image]
    
    begin
      # Delete original image
      begin
        file = github_client.contents(REPO_NAME, path: "images/albums/#{gallery}/#{image}")
        github_client.delete_contents(
          REPO_NAME,
          "images/albums/#{gallery}/#{image}",
          "Delete #{image}",
          file.sha,
          branch: BRANCH
        )
      rescue Octokit::NotFound
        logger.warn "Original image not found: #{image}"
      end
      
      # Delete thumbnail
      begin
        thumb = github_client.contents(REPO_NAME, path: "images/albums/#{gallery}/thumbs/#{image}")
        github_client.delete_contents(
          REPO_NAME,
          "images/albums/#{gallery}/thumbs/#{image}",
          "Delete thumbnail for #{image}",
          thumb.sha,
          branch: BRANCH
        )
      rescue Octokit::NotFound
        logger.warn "Thumbnail not found: #{image}"
      end
      
      # Update gallery index
      remove_from_gallery_yaml(gallery, image)
      
      session[:flash] = { success: "Image deleted successfully!" }
    rescue => e
      logger.error "Delete failed: #{e.message}"
      session[:flash] = { error: "Delete failed: #{e.message}" }
    end
    
    redirect "/admin/gallery/#{gallery}"
  end

  # Temporary test route - remove in production
  get '/admin/test-env' do
    content_type :json
    stored_hash = ENV['ADMIN_PASSWORD'].to_s.strip.gsub(/["']/, '')
    {
      admin_username: ENV['ADMIN_USERNAME'],
      admin_password_raw: ENV['ADMIN_PASSWORD'].inspect,
      admin_password_processed: stored_hash,
      hash_valid: stored_hash.start_with?('$2a$'),
      hash_length: stored_hash.length,
      session_secret: ENV['SESSION_SECRET'] ? 'set' : 'not set',
      rack_env: ENV['RACK_ENV']
    }.to_json
  end

  # Add this temporarily and remove after testing
  get '/admin/test-password' do
    password = 'Brikjr'  # The password you used
    stored_hash = ENV['ADMIN_PASSWORD']
    content_type :json
    {
      stored_hash: stored_hash,
      test_result: BCrypt::Password.new(stored_hash) == password,
      env_username: ENV['ADMIN_USERNAME']
    }.to_json
  end

  private

  def remove_from_gallery_yaml(gallery, filename)
    path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
    
    begin
      # Get current file
      file = github_client.contents(REPO_NAME, path: path)
      content = Base64.decode64(file.content)
      
      # Remove the image entry and its associated caption and copyright lines
      lines = content.lines
      new_lines = []
      skip_next_lines = 0
      
      lines.each do |line|
        if skip_next_lines > 0
          skip_next_lines -= 1
          next
        end
        
        if line.include?("/#{filename}")
          skip_next_lines = 2  # Skip the next 2 lines (caption and copyright)
        else
          new_lines << line
        end
      end
      
      updated_content = new_lines.join
      
      # Update file
      github_client.update_contents(
        REPO_NAME,
        path,
        "Remove #{filename} from gallery index",
        file.sha,
        updated_content,
        branch: BRANCH
      )
    rescue => e
      logger.error "Error removing image from index: #{e.message}"
      raise e
    end
  end

  def process_image(gallery, file, filename)
    begin
      # Save temp file
      temp_path = File.join(Dir.tmpdir, filename)
      File.write(temp_path, file.read)
      
      # Call Python handler
      cmd = [
        'python3', 
        File.join(__dir__, 'image_handler.py'),
        'process',
        temp_path,
        gallery,
        filename,
        params[:caption].to_s,
        params[:copyright].to_s
      ]
      
      stdout, stderr, status = Open3.capture3(*cmd)
      
      if status.success?
        true
      else
        logger.error "Python error: #{stderr}"
        false
      end
    ensure
      File.unlink(temp_path) if temp_path && File.exist?(temp_path)
    end
  end
end 