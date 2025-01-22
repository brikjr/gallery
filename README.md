# Photography Portfolio Website

A responsive photography portfolio website built with Jekyll, featuring lazy loading images, masonry grid layouts, and smooth transitions.

## Known Issues

1. **Image Upload Issues**
   - Currently experiencing encoding errors when uploading images
   - Error: "Upload failed: incompatible character encodings: ASCII-8BIT and UTF-8"
   - Temporary workaround: Use GitHub interface to upload images directly

2. **YAML Formatting Issues** 
   - Duplicate keys appearing in gallery index files
   - Emoji encoding problems with album-title
   - Title and description fields sometimes duplicating

## Prerequisites

Before you begin, ensure you have the following installed with these specific versions:

- [Ruby](https://www.ruby-lang.org/en/downloads/) (version 3.1.0)
  ```bash
  # Check Ruby version
  ruby --version
  
  # If using rbenv to install Ruby
  rbenv install 3.1.0
  rbenv global 3.1.0
  ```

- [RubyGems](https://rubygems.org/pages/download) (version 3.3.0 or higher)
  ```bash
  # Check RubyGems version
  gem --version
  
  # Update RubyGems
  gem update --system
  ```

- [Bundler](https://bundler.io/) (version 2.3.0)
  ```bash
  # Install specific bundler version
  gem install bundler -v '2.3.0'
  
  # Check bundler version
  bundle --version
  ```

- [Jekyll](https://jekyllrb.com/docs/installation/) (version 3.8.5)
  ```bash
  # Jekyll will be installed via bundler
  ```

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. **Install Jekyll and dependencies**
   ```bash
   # Install specific bundler version if not installed
   gem install bundler -v '2.3.0'

   # Install project dependencies
   bundle install
   ```

3. **Verify installations**
   ```bash
   # Verify Ruby version
   ruby --version  # Should show 3.1.0
   
   # Verify Bundler version
   bundle --version  # Should show 2.3.0
   
   # Verify Jekyll version
   bundle exec jekyll --version  # Should show 3.8.5
   ```

## Running Locally

1. **Start the Jekyll server**
   ```bash
   bundle exec jekyll serve --port 5000 --livereload
   ```
   This will start a local server with live reload enabled.

2. **View the website**
   - Open your browser and go to: `http://localhost:5000/gallery/`

## Troubleshooting

### Image Upload Errors

If you encounter the ASCII-8BIT and UTF-8 encoding error:

1. **Manual Upload Method**
   ```bash
   # Instead of using the admin panel, upload directly to GitHub:
   1. Navigate to images/albums/[gallery_name]/ in your repository
   2. Use the "Add file" button to upload images
   3. Manually update the gallery's index.html
   ```

2. **Temporary File Upload Fix**
   ```ruby
   # In admin/app.rb, try adding:
   file.read.force_encoding('UTF-8')
   ```

### YAML Formatting Issues

If you see duplicate keys in gallery index files:

1. **Manual YAML Fix**
   ```yaml
   # Correct format should be:
   ---
   layout: page
   title: "Gallery Name"
   description: "Gallery Description"
   active: gallery
   header-img: "/path/to/image"
   album-title: "🎞️"
   images:
     - image_path: /path/to/image
       caption: Image Caption
       copyright: © Copyright
   ---
   ```

2. **Check File Encoding**
   ```bash
   # Ensure all files are UTF-8
   file -I images/*/index.html
   
   # Convert if needed
   iconv -f ISO-8859-1 -t UTF-8 file.html > file.html.new
   mv file.html.new file.html
   ```

### Admin Panel Issues

If the admin panel is not working:

1. **Check Environment Variables**
   ```bash
   # Required env vars:
   export GITHUB_TOKEN="your_token"
   export REPO_NAME="username/repo"
   export ADMIN_USERNAME="admin"
   export ADMIN_PASSWORD="password"
   export SESSION_SECRET="random_string"
   ```

2. **Verify Permissions**
   - Ensure GitHub token has `repo` scope
   - Check repository permissions
   - Verify branch protection rules

3. **Debug Mode**
   ```bash
   # Start admin panel in debug mode
   RACK_ENV=development ruby admin/app.rb
   ```

### Development Tips

1. **Local Testing**
   ```bash
   # Start Jekyll with detailed logs
   bundle exec jekyll serve --port 5000 --livereload --verbose
   ```

2. **Monitor GitHub API Rate Limits**
   ```ruby
   # Add to admin/app.rb:
   puts github_client.rate_limit.remaining
   ```

3. **Check File Permissions**
   ```bash
   # Ensure proper permissions
   chmod -R 755 images/
   chmod -R 644 images/*/*.html
   ```

## Contributing

Please report any issues or bugs in the GitHub issue tracker. Pull requests are welcome!

## License

[Previous license section remains the same...]