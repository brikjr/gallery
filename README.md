# Photography Portfolio Website

A responsive photography portfolio website built with Jekyll, featuring lazy loading images, masonry grid layouts, and smooth transitions.

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

## Troubleshooting Common Installation Issues

1. **Ruby version conflicts**
   ```bash
   # If using rbenv
   rbenv install 3.1.0
   rbenv local 3.1.0
   gem install bundler -v '2.3.0'
   bundle install
   ```

2. **Bundler version issues**
   ```bash
   gem uninstall bundler
   gem install bundler -v '2.3.0'
   bundle install
   ```

3. **Jekyll build errors**
   ```bash
   bundle update
   bundle exec jekyll doctor
   ```

## Project Structure

For template checkout to ["Template branch"](https://github.com/brikjr/gallery/tree/template)