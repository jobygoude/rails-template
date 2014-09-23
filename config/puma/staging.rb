#!/usr/bin/env puma

# application path, ex: /srv/app
ROOT_PATH = ''.freeze
SHRD_PATH = "#{ROOT_PATH}/shared".freeze
CURT_PATH = "#{ROOT_PATH}/current".freeze

directory "#{ROOT_PATH}/current"

environment 'staging'

daemonize true

pidfile "#{SHRD_PATH}/tmp/pids/puma.pid"

state_path "#{SHRD_PATH}/tmp/pids/puma.state"

stdout_redirect "#{SHRD_PATH}/log/puma.out.log", "#{SHRD_PATH}/log/puma.err.log", true

threads 0, 16

bind "unix://#{SHRD_PATH}/tmp/sockets/puma.sock"

on_restart do
  puts 'On restart...'
  puts 'Refreshing Gemfile'
  ENV["BUNDLE_GEMFILE"] = "#{CURT_PATH}/Gemfile"
end

activate_control_app "unix://#{SHRD_PATH}/tmp/sockets/pumactl.sock"
