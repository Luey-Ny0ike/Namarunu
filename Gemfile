# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
require 'net/http'

ruby file: ".ruby-version"

# Drivers
gem 'rails', github: 'rails/rails', branch: "main"
gem 'pg', '>= 0.18', '< 2.0'
gem 'puma', '~> 6.4'

# Frontend
gem "importmap-rails", "~> 2.2"
gem 'propshaft', '~> 1.3'


gem "stimulus-rails", "~> 1.3"
gem 'turbo-rails', '~> 2.0'

gem 'jbuilder', '~> 2.7'
gem "mutex_m"


gem 'africastalking-ruby', '~> 2.1', '>= 2.1.5'
gem 'wicked'
gem 'will_paginate', '~> 3.1.0'

# Use Active Storage variant
gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false
gem 'foreman', '~> 0.90.0'
gem 'tzinfo-data', platforms: %i[ windows jruby]

# Google recaptcha
gem "recaptcha", "~> 5.21"

group :development, :test do
  gem 'byebug', platforms: %i[ windows ]
  gem 'rspec-rails'
  # gem 'launchy'
  gem 'pry'
  gem 'shoulda-matchers'
  gem "dotenv-rails", "~> 3.2"
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'web-console', '>= 3.3.0'
  gem 'capistrano', '~> 3.11', require: false
  gem 'capistrano3-puma',   require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-rvm', require: false
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end
