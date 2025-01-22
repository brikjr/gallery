source "https://rubygems.org"

ruby "3.1.0"

# Core Jekyll
gem 'jekyll', '~> 4.3.2'
gem "webrick", "~> 1.8" # Required for Ruby 3+

# Jekyll plugins
group :jekyll_plugins do
  gem "jekyll-feed", "0.6.0"
  gem "jekyll-paginate", "1.1.0"
  gem "jekyll-sitemap", "1.4.0"
end

# Admin panel dependencies
gem "sinatra", "~> 3.0"
gem "mini_magick", "~> 4.12"
gem "bcrypt", "~> 3.1"
gem "octokit", "~> 5.0"
gem 'rexml'
# Development dependencies
group :development do
  # Windows does not include zoneinfo files
  gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
  # Performance-booster for watching directories on Windows
  gem "wdm", "~> 0.1.0" if Gem.win_platform?
end

# Add these if not already present
gem 'rack'
gem 'rackup'