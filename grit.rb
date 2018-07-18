#!/usr/bin/env ruby
# frozen_string_literal: true

# Grit is a way to manage multiple repos in a git repository seamlessly
# using the git CL tool
# It serves 'only' to be a mapping tool; it doesn't create/delete repositories
# only .grit/config.yml

# What Grit should do:
# - Proxy the git API
# - Not get in the way
# - Allow the user to make the normal git choices due to that proxy

# Sample config.yml
# ---
# :root: /Users/john/my_project
# :repositories:
#   - :name: Sproutcore
#     :path: frameworks/sproutcore
#   - :name: SCUI
#     :path: frameworks/scui

require 'yaml'
require 'fileutils'

# Grit Class
class Grit
  def initialize_grit(args)
    location = args[0] || Dir.pwd

    if File.directory?(location)
      directory = File.join(location, '.grit')
      FileUtils.mkdir(directory) unless File.directory?(directory)

      config_file = directory + '/config.yml'
      unless File.exist?(config_file)
        config = {}
        config[:root] ||= Dir.pwd
        config[:repositories] ||= []

        open(directory + '/config.yml', 'w') { |f| YAML.dump(config, f) }
      end
    else
      puts "Directory doesn't exist!"
    end
  end

  def load_config
    open(File.join(FileUtils.pwd, '.grit/config.yml')) { |f| YAML.load(f) }
  end

  def write_config(config)
    open(File.join(FileUtils.pwd, '.grit/config.yml'), 'w') { |f| YAML.dump(config, f) }
  end

  def add_repository(args)
    config = load_config
    name = args[0]
    path = args[1]

    config[:repositories].push(name: name, path: path)
    write_config(config)
  end

  def get_repository(name)
    config = load_config
    config[:repositories].detect { |f| f[:name] == name }
  end

  def perform_on(repo_name, args)
    repo = get_repository(repo_name)
    args = args.join(' ') unless args.class == String

    if repo.nil? || repo[:path].nil? || !File.exist?(repo[:path])
      puts "Can't find repository: #{repo_name} at location #{repo[:path]}"
      abort
    end

    Dir.chdir(repo[:path]) do |_d|
      perform(args, repo[:name])
    end
  end

  def remove_repository(names)
    config = load_config
    puts config.inspect

    match = get_repository(names[0])
    if match.nil?
      puts 'Could not find repository'
    elsif config[:repositories].delete(match)
      write_config(config)
      puts "Removed repository #{name} from grit"
    else
      puts "Unable to remove repository #{name}"
    end
  end

  def perform(to_do, name)
    puts '-' * 80
    puts "# #{name.upcase} -- git #{to_do}" unless name.nil?
    puts `git #{to_do}`
    puts '-' * 80
    puts ''
  end

  def proceed(args)
    config = load_config
    repositories = if config[:ignore_root]
                     config[:repositories]
                   else
                     config[:repositories].unshift(name: 'Root', path: config[:root])
                   end

    to_do = args.map { |x| x.include?(' ') ? "\"#{x}\"" : x }.join(' ')

    repositories.each do |repo|
      if repo[:path].nil?
        puts "Can't find repository: #{repo[:path]}"
        continue
      end

      Dir.chdir(repo[:path]) do |_d|
        perform(to_do, repo[:name])
      end
    end
  end
end

project = Grit.new
case ARGV[0]
when 'init'
  project.initialize_grit(ARGV[1..-1])
when 'add-repository'
  project.add_repository(ARGV[1..-1])
when 'remove-repository'
  project.remove_repository(ARGV[1..-1])
when 'on'
  project.perform_on(ARGV[1], ARGV[2..-1])
else
  project.proceed ARGV
end
