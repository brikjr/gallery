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
require 'sinatra/flash'
require_relative 'git_sync'

# Load environment variables before defining the class
Dotenv.load('.env.local', '.env') if ENV['RACK_ENV'] != 'production'

class AdminPanel < Sinatra::Base
  configure do
    enable :logging
    
    # Set up logger
    file = File.new("admin.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
    logger = Logger.new(file)
    set :logger, logger

    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, 'views')
    set :public_folder, File.join(settings.root, 'public')
    enable :sessions
    set :session_secret, ENV['SESSION_SECRET']
    set :protection, true
    enable :dump_errors if development?
    
    # Add local repository path
    set :repo_path, ENV['LOCAL_REPO_PATH'] || File.expand_path('../..', __FILE__)

    # Enable flash messages
    register Sinatra::Flash
  end

  # Constants
  GITHUB_TOKEN = ENV['GITHUB_TOKEN']
  REPO_NAME = ENV['REPO_NAME']
  BRANCH = 'gh-pages'
  ADMIN_USERNAME = ENV['ADMIN_USERNAME'] || 'admin'
  ADMIN_PASSWORD = ENV['ADMIN_PASSWORD']

  # Before filters
  before do
    check_env_vars
    session[:csrf] ||= SecureRandom.base64(32)
    logger.info "Request: #{request.path_info}"
    logger.info "Session: #{session.inspect}"
    logger.info "Authenticated: #{authenticated?}"
  end

  before '/dashboard' do
    require_auth
  end

  before '/gallery/*' do
    require_auth
  end

# Helpers
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

    def require_auth
      authenticate!
    end

    def check_env_vars
      required_vars = %w[ADMIN_USERNAME ADMIN_PASSWORD SESSION_SECRET GITHUB_TOKEN REPO_NAME]
      missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
      
      unless missing_vars.empty?
        logger.error "Missing required environment variables: #{missing_vars.join(', ')}"
        halt 500, "Server configuration error. Check logs for details."
      end
    end

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
        client.auto_paginate = true
        client
      end
    end

    def normalize_gallery_name(name)
      name == 'landscapes' ? 'landscape' : name
    end

    def get_galleries
      contents = github_client.contents(REPO_NAME, path: 'images', ref: BRANCH)
      galleries = contents.select { |c| c.type == 'dir' && c.name != 'slider' }.map(&:name)
      galleries.map { |g| g == 'landscapes' ? 'landscape' : g }
    end

    def get_gallery_images(gallery)
      begin
        contents = github_client.contents(REPO_NAME, path: "images/albums/#{gallery}")
        
        images = contents.select do |file| 
          file.type == 'file' && 
          !file.path.include?('/thumbs/') && 
          file.name =~ /\.(jpg|jpeg|png|gif)$/i
        end

        metadata = begin
          index_path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
          index_content = github_client.contents(REPO_NAME, path: index_path, ref: BRANCH)
          file_content = Base64.decode64(index_content.content)
          front_matter = file_content.split('---')[1]
          
          if front_matter
            yaml_data = YAML.safe_load(front_matter)
            yaml_data['images'] if yaml_data
          end
        rescue Octokit::NotFound
          logger.error "Gallery index not found for #{gallery}"
          nil
        rescue => e
          logger.error "Error parsing gallery metadata: #{e.message}"
          nil
        end || []

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

# Slider management helpers
def get_slider_images
    begin
      file = github_client.contents(REPO_NAME, path: "images/index.html", ref: BRANCH)
      content = Base64.decode64(file.content)
      parts = content.split(/^---\s*$/)
      front_matter = YAML.safe_load(parts[1]) || {}
      
      images = front_matter['images'] || []
      
      # Enhance images with raw GitHub URLs
      images.map do |img|
        path = img['image_path'].sub(/^\//, '') # Remove leading slash
        {
          'image_path' => img['image_path'],
          'gallery-folder' => img['gallery-folder'],
          'gallery-name' => img['gallery-name'],
          'url' => "https://raw.githubusercontent.com/#{REPO_NAME}/#{BRANCH}/#{path}"
        }
      end
    rescue => e
      logger.error "Error getting slider images: #{e.message}"
      []
    end
  end

  def update_slider_image(old_path, new_path, gallery_name)
    begin
      file = github_client.contents(REPO_NAME, path: "images/index.html", ref: BRANCH)
      content = Base64.decode64(file.content)
      parts = content.split(/^---\s*$/)
      front_matter = YAML.safe_load(parts[1]) || {}
      
      if front_matter['images']
        front_matter['images'].each do |img|
          if img['image_path'] == old_path
            img['image_path'] = new_path
            img['gallery-folder'] = "/images/#{gallery_name.downcase}/"
            img['gallery-name'] = gallery_name
          end
        end
      end

      new_content = "---\n#{front_matter.to_yaml}---#{parts[2]}"
      
      github_client.update_contents(
        REPO_NAME,
        "images/index.html",
        "Update slider image",
        file.sha,
        new_content,
        branch: BRANCH
      )
      true
    rescue => e
      logger.error "Error updating slider image: #{e.message}"
      false
    end
  end

  # Header image helpers
  def get_header_image(gallery)
    begin
      # First get the header path from index.html
      path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
      index_file = github_client.contents(REPO_NAME, path: path, ref: BRANCH)
      content = Base64.decode64(index_file.content)
      front_matter = YAML.safe_load(content.split(/^---\s*$/)[1]) || {}
      header_path = front_matter['header-img']
      
      return nil unless header_path

      # Convert path to raw GitHub URL
      image_path = header_path.sub(/^\//, '') # Remove leading slash
      raw_url = "https://raw.githubusercontent.com/#{REPO_NAME}/#{BRANCH}/#{image_path}"
      
      {
        'path' => header_path,
        'url' => raw_url
      }
    rescue => e
      logger.error "Error getting header image for #{gallery}: #{e.message}"
      nil
    end
  end

  def update_header_image(gallery, new_path)
    begin
      path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
      file = github_client.contents(REPO_NAME, path: path, ref: BRANCH)
      content = Base64.decode64(file.content)
      parts = content.split(/^---\s*$/)
      front_matter = YAML.safe_load(parts[1]) || {}
      
      front_matter['header-img'] = new_path
      
      new_content = "---\n#{front_matter.to_yaml}---#{parts[2]}"
      
      github_client.update_contents(
        REPO_NAME,
        path,
        "Update header image",
        file.sha,
        new_content,
        branch: BRANCH
      )
      true
    rescue => e
      logger.error "Error updating header image: #{e.message}"
      false
    end
  end

# Album creation helpers
def create_album_structure(name, description)
    begin
      name = name.downcase
      
      # Create directories
      [
        "images/albums/#{name}",
        "images/#{name}"
      ].each do |dir|
        FileUtils.mkdir_p(File.join(settings.repo_path, dir))
      end

      # Create index.html with boilerplate
      index_content = create_album_template(name, description)

      # Create the index.html file in GitHub
      github_client.create_contents(
        REPO_NAME,
        "images/#{name}/index.html",
        "Create new album: #{name}",
        index_content,
        branch: BRANCH
      )

      # Update main index.html to include the new album
      update_main_index(name)

      true
    rescue => e
      logger.error "Error creating album structure: #{e.message}"
      false
    end
  end

  def create_album_template(name, description)
    <<~CONTENT
      ---
      layout: page
      title: "#{name.capitalize}"
      description: "#{description}"
      active: gallery
      header-img: "/images/albums/#{name}/header.jpg"
      album-title: "🎞️"
      images:
      ---
      #{File.read(File.join(settings.root, 'views', 'album_template.html'))}
    CONTENT
  end

  def update_main_index(album_name)
    begin
      file = github_client.contents(REPO_NAME, path: "images/index.html", ref: BRANCH)
      content = Base64.decode64(file.content)
      parts = content.split(/^---\s*$/)
      front_matter = YAML.safe_load(parts[1]) || {}
      
      front_matter['images'] ||= []
      unless front_matter['images'].any? { |img| img['gallery-name'].downcase == album_name.downcase }
        front_matter['images'] << {
          'image_path' => "/images/albums/#{album_name}/header.jpg",
          'gallery-folder' => "/images/#{album_name}/",
          'gallery-name' => album_name.capitalize
        }
      end

      new_content = "---\n#{front_matter.to_yaml}---#{parts[2]}"
      github_client.update_contents(
        REPO_NAME,
        "images/index.html",
        "Add new album to index: #{album_name}",
        file.sha,
        new_content,
        branch: BRANCH
      )
    rescue => e
      logger.error "Error updating main index: #{e.message}"
      raise e
    end
  end

  def default_copyright
    '© Brik'
  end

  def flash
    session[:flash] ||= {}
  end

  def clear_flash
    session.delete(:flash)
  end
end # End helpers block

# Basic routes
get '/' do
    redirect '/admin/login'
  end
  
  get '/login' do
    erb :login
  end
  
  post '/login' do
    if params[:password] == ENV['ADMIN_PASSWORD']
      session[:authenticated] = true
      redirect '/admin/dashboard'
    else
      @error = "Invalid password"
      erb :login
    end
  end
  
  get '/logout' do
    session.clear
    redirect '/admin/login'
  end
  
  get '/dashboard' do
    require_auth
    @galleries = get_galleries
    erb :dashboard
  end
  
  # Gallery routes
  get '/gallery/:name' do
    require_auth
    @gallery = normalize_gallery_name(params[:name])
    @images = get_gallery_images(@gallery)
    @flash_messages = session[:flash]
    clear_flash
    erb :gallery
  end
  
  post '/gallery/:name/upload' do
    authenticate!
    begin
      gallery = params[:name]
      file = params[:file]
      caption = params[:caption]
      copyright = params[:copyright]
      
      if file
        filename = file[:filename]
        success = process_image(file, gallery, filename, caption, copyright)
        flash[:success] = success ? "Successfully uploaded #{filename}" : "Failed to upload image"
      else
        flash[:error] = "No file selected"
      end
    rescue => e
      logger.error "Upload error: #{e.message}"
      flash[:error] = "Upload error: #{e.message}"
    end
    redirect "/admin/gallery/#{gallery}"
  end
  
  # Image deletion route
  post '/gallery/:name/delete/:image' do
    require_auth
    gallery = normalize_gallery_name(params[:name])
    image = params[:image]
    
    begin
      # First, remove from index.html to update metadata
      remove_from_gallery_yaml(gallery, image)
      
      # Then delete the actual image files
      ["images/albums/#{gallery}/#{image}", "images/albums/#{gallery}/thumbs/#{image}"].each do |file_path|
        begin
          file = github_client.contents(REPO_NAME, path: file_path, ref: BRANCH)
          github_client.delete_contents(
            REPO_NAME,
            file_path,
            "Delete #{image}",
            file.sha,
            branch: BRANCH
          )
          logger.info "Successfully deleted #{file_path}"
        rescue Octokit::NotFound
          logger.warn "File not found: #{file_path}"
        end
      end
      
      # Clean up local files
      [
        File.join(settings.repo_path, 'images', 'albums', gallery, image),
        File.join(settings.repo_path, 'images', 'albums', gallery, 'thumbs', image)
      ].each do |local_path|
        File.delete(local_path) if File.exist?(local_path)
      end
      
      session[:flash] = { success: "Image and metadata deleted successfully!" }
    rescue => e
      logger.error "Delete failed: #{e.message}"
      logger.error e.backtrace.join("\n")
      session[:flash] = { error: "Delete failed: #{e.message}" }
    end
    
    redirect "/admin/gallery/#{gallery}"
  end
  
  # Slider management routes
  get '/slider' do
    require_auth
    @slider_images = get_slider_images
    erb :slider_management
  end
  
  post '/slider/update' do
    require_auth
    if update_slider_image(params[:old_path], params[:new_path], params[:gallery_name])
      flash[:success] = "Slider image updated successfully!"
    else
      flash[:error] = "Failed to update slider image"
    end
    redirect '/admin/slider'
  end
  
  # Header management routes
  get '/gallery/:name/header' do
    require_auth
    @gallery = normalize_gallery_name(params[:name])
    @header_image = get_header_image(@gallery)
    erb :header_management
  end
  
  post '/gallery/:name/header' do
    require_auth
    gallery = normalize_gallery_name(params[:name])
    if update_header_image(gallery, params[:header_path])
      flash[:success] = "Header image updated successfully!"
    else
      flash[:error] = "Failed to update header image"
    end
    redirect "/admin/gallery/#{gallery}"
  end
  
  # Album creation routes
  get '/albums/new' do
    require_auth
    erb :new_album
  end
  
  post '/albums/create' do
    require_auth
    name = params[:name].strip.downcase.gsub(/\s+/, '-')
    description = params[:description].strip
  
    if create_album_structure(name, description)
      flash[:success] = "Album '#{name}' created successfully!"
      redirect '/admin/dashboard'
    else
      flash[:error] = "Failed to create album"
      redirect '/admin/albums/new'
    end
  end
  
  # GitHub sync route
  post '/push' do
    authenticate!
    begin
      git_sync = GitSync.new(settings.repo_path, BRANCH)
      success, message = git_sync.sync_with_remote
      
      flash[:success] = success ? "Successfully synchronized with GitHub! 🚀" : "Failed to sync: #{message}"
    rescue => e
      logger.error "Sync error: #{e.message}"
      flash[:error] = "Sync error: #{e.message}"
    end
    
    redirect '/admin/dashboard'
  end
  
  # Test routes (can be removed in production)
  get '/test' do
    content_type :text
    'Admin panel is working!'
  end
  
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
  
  get '/admin/test-password' do
    password = 'Brikjr'
    stored_hash = ENV['ADMIN_PASSWORD']
    content_type :json
    {
      stored_hash: stored_hash,
      test_result: BCrypt::Password.new(stored_hash) == password,
      env_username: ENV['ADMIN_USERNAME']
    }.to_json
  end
  
  # Error handling
  not_found do
    status 404
    "Page not found"
  end
  
  error do
    status 500
    "Something went wrong - " + env['sinatra.error'].message
  end

  private

  def remove_from_gallery_yaml(gallery, filename)
    path = gallery == 'landscape' ? 'images/landscapes/index.html' : "images/#{gallery}/index.html"
    image_path_to_remove = "/images/albums/#{gallery}/#{filename}"
    
    begin
      file = github_client.contents(REPO_NAME, path: path, ref: BRANCH)
      content = Base64.decode64(file.content)
      
      # Get everything between the first pair of --- markers
      parts = content.split(/^---\s*$/, 3)
      yaml_content = parts[1]
      rest_content = parts[2] || ''

      if yaml_content.nil?
        logger.error "Invalid index.html format - no YAML content found"
        return false
      end

      begin
        front_matter = YAML.safe_load(yaml_content) || {}
      rescue => e
        logger.error "YAML parsing error: #{e.message}"
        logger.error "YAML content that failed to parse: #{yaml_content}"
        return false
      end

      if front_matter['images']
        # Log initial state
        logger.info "Current images count: #{front_matter['images'].length}"
        
        # Keep track of removed images
        original_count = front_matter['images'].length
        
        # Only remove exact match
        front_matter['images'].reject! do |img|
          is_match = img['image_path'] == image_path_to_remove
          if is_match
            logger.info "Found exact match for removal: #{img['image_path']}"
          end
          is_match
        end
        
        removed_count = original_count - front_matter['images'].length
        logger.info "After removal - images count: #{front_matter['images'].length}"

        # Construct new YAML properly
        yaml_string = front_matter.to_yaml.gsub(/^---\n/, '').gsub(/\.\.\.\n/, '')

        # Rebuild the file content with proper spacing
        new_content = "---\n#{yaml_string}---#{rest_content}"
        new_content += "\n" unless new_content.end_with?("\n")

        github_client.update_contents(
          REPO_NAME,
          path,
          "Remove #{filename} from gallery index",
          file.sha,
          new_content,
          branch: BRANCH
        )
        
        logger.info "Successfully updated index file"
        return true
      else
        logger.warn "No images section found in front matter"
        return false
      end
      
    rescue => e
      logger.error "Error removing image from index: #{e.message}"
      logger.error "Image path attempted to remove: #{image_path_to_remove}"
      logger.error e.backtrace.join("\n")
      raise e
    end
  end

  def process_image(file, gallery, filename, caption, copyright)
    begin
      # Create directories if they don't exist
      gallery_path = File.join('images', 'albums', gallery)
      FileUtils.mkdir_p(gallery_path)

      # Upload the original file
      tempfile = file[:tempfile]
      content = Base64.strict_encode64(File.read(tempfile.path))

      # Try to get existing file first
      file_path = "images/albums/#{gallery}/#{filename}"
      begin
        existing_file = github_client.contents(REPO_NAME, path: file_path, ref: BRANCH)
        
        # Update existing file
        github_client.update_contents(
          REPO_NAME,
          file_path,
          "Update #{filename}",
          existing_file.sha,
          content,
          branch: BRANCH
        )
      rescue Octokit::NotFound
        # Create new file if it doesn't exist
        github_client.create_contents(
          REPO_NAME,
          file_path,
          "Add #{filename}",
          content,
          branch: BRANCH
        )
      end

      # Update gallery index
      update_gallery_yaml(gallery, filename)

      # Also save locally if local repo exists
      if settings.repo_path
        local_path = File.join(settings.repo_path, 'images', 'albums', gallery, filename)
        FileUtils.mkdir_p(File.dirname(local_path))
        FileUtils.cp(tempfile.path, local_path)
      end
      
      return true
    rescue => e
      logger.error "Error processing image: #{e.message}"
      logger.error e.backtrace.join("\n")
      return false
    end
  end
end # End AdminPanel class