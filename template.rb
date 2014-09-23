require 'etc'

username = Etc.getlogin

# create .rbenv file
create_file ".ruby-version", "2.1.2"

# add gems
gem 'pg'
gem 'slim-rails'

if yes?("Do you want to use devise ?")
  gem 'devise'
  gem 'devise-i18n'
  # setup devise
  generate "devise:install"
  generate "devise User"
  generate "devise:views"
end

%w(whenever kaminari cancan).each do |g|
  gem g if yes?("Do you need #{g} ?")
end

if yes?("Do you need mootools?")
  gem 'mootools-rails'
elsif yes?("Do you need jquery?")
  if yes?("Do you need jquery-ui ?")
    gem 'jquery-ui-rails'
  end
end

if yes?("Do you want to use rspec instead of minitest ?")
  gem_group :test do
    gem 'rspec-rails'
    gem 'spork-rails'
    gem 'guard-spork'
    gem 'guard-rspec'
    gem 'shoulda-matchers'
  end
else
  gem_group :test do
    gem 'minitest-spec-rails'
    gem 'guard-minitest'
    gem 'turn'
  end
  run "guard init minitest"
  environment "config.minitest_spec_rails.mini_shoulda = true", env: "test"

  # Add require and config for minitest
  insert_into_file 'test/test_helper.rb', "require 'turn/autorun'", :after => "require 'rails/test_help'\n"
  insert_into_file 'test/test_helper.rb', "Turn.config.format = :progress\n\n", :after => "require 'turn/autorun'\n"
end

gem 'puma'
gem 'hipchat'
gem 'airbrake'

gem 'capistrano',         '~> 3.2.0', require: false
gem 'capistrano-rbenv',   '~> 2.0',   require: false
gem 'capistrano-bundler', '~> 1.1.2', require: false
gem 'capistrano-rails',   '~> 1.1.1', require: false
gem 'capistrano3-puma',               require: false
gem 'rack-cache', :require => 'rack/cache'

gem_group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'awesome_print'
  gem 'pry-rails'
  gem 'debugger2'
  gem 'ruby-prof'
end

gem_group :doc do
  gem 'yard'
  gem 'rails-erd'
end

# install gems
run 'bundle install --without=production'
run 'bundle exec cap install'
run 'mkdir config/deploy'

# edit database config file
remove_file 'config/database.yml'
file 'config/database.yml', <<-END
development:
  adapter: postgresql
  database: #{app_name}_development
  host: localhost
  username: #{username}
  password:
  encoding: utf8

test:
  adapter: postgresql
  database: #{app_name}_test
  host: localhost
  username: #{username}
  password:
  encoding: utf8
END

remove_file 'README.rdoc'
file 'README.md'

rake "db:create"

environment "config.action_mailer.default_url_options = {host: 'http://localhost:3000'}", env: 'development'

rake "db:create"

# remove defaults files
remove_file 'public/index.html'
remove_file 'app/assets/images/rails.png'

# copy database.yml file
run 'cp config/database.yml config/database.example.yml'

# add database.yml to .gitignore
run "echo 'config/database.yml' >> .gitignore"
run "echo 'vendor/bundle' >> .gitignore"

# Get latest fr.yml from github
get "https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/fr.yml", "config/locales/fr.yml"

# Sets some default config per env
environment "config.i18n.default_locale = :fr"
environment "config.time_zone = 'Paris'"

# setup git and git-flow then initial commit
git :init
git flow: "init"
git add: "."
git commit: "-a -m 'Initial commit'"
