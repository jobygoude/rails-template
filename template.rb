require 'etc'

GITHUB_BASE_URL = "https://raw.githubusercontent.com/synbioz/rails-template/master".freeze
RUBY_VERSION    = "2.1.2".freeze

username        = Etc.getlogin

# create .rbenv file
create_file ".ruby-version", RUBY_VERSION

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

gem "capistrano-redmine", :git => "https://github.com/synbioz/capistrano-redmine.git", require: false

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

# copy default rake tasks
run "mkdir -p lib/capistrano/tasks"
get "#{GITHUB_BASE_URL}/capistrano/tasks/no-robot.rake", "lib/capistrano/tasks/no-robot.rake"
get "#{GITHUB_BASE_URL}/capistrano/tasks/version.rake", "lib/capistrano/tasks/version.rake"
get "#{GITHUB_BASE_URL}/capistrano/tasks/remote.rake", "lib/capistrano/tasks/remote.rake"

# copy puma configuration
run "mkdir -p config/puma"
get "#{GITHUB_BASE_URL}/config/puma/production.rb", "config/puma/production.rb"
get "#{GITHUB_BASE_URL}/config/puma/staging.rb", "config/puma/staging.rb"

file 'config/deploy/staging.rb', <<-END

server '', user: 'synbioz', roles: %w{web app db}

set :rails_env, 'staging'
set :branch, 'develop'
set :redmine_site, "https://redmine.site"
set :redmine_token, "token_utilisateur"
set :redmine_options, { ssl: { cert: nil, key: nil } }
set :redmine_projects, "mon_project"
# resolved
set :redmine_from_status, 3
# deployed
set :redmine_to_status, 7

after 'deploy', 'copy_no_robots_file'
after "deploy", "redmine:update"
END

file 'config/deploy.rb', <<-END
lock ''

set :user, "synbioz"
set :application, ''
set :repo_url, ''

set :deploy_to, ''

set :log_level, :debug
set :pty, false
set :ssh_options, { forward_agent: true }

set :linked_files, %w{
  config/database.yml
  config/secrets.yml
}

set :linked_dirs, %w{
  log
  tmp/pids
  tmp/cache
  tmp/sockets
  vendor/bundle
  public/system
}

set :default_env, { path: "~/.rbenv/bin:~/.rbenv/shims:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH" }

set :bundle_flags, "--quiet"
set :rbenv_type, :user
set :rbenv_ruby, "#{RUBY_VERSION}"

set :puma_conf, -> { File.join(release_path, 'config', 'puma', "#{fetch(:stage)}.rb") }
# Do not perform the puma's check task because the config file
# is in the source tree. The check method will try to upload
# a config file but will never succeed.
Rake::Task['puma:check'].clear

set :hipchat_token, ""
set :hipchat_room_name, ""
set :hipchat_announce, false

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      Rake::Task["puma:restart"].invoke
    end
  end

  after :publishing, :restart

  desc 'Runs rake db:seed'
  task :seed => [:set_rails_env] do
    on primary fetch(:migration_role) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end

  after :migrate, :seed

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
    end
  end
end

after "deploy", "deploy:generate_version"
after "deploy:finished", "airbrake:deploy"
END

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
