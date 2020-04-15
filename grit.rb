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
# :root: /Users/john/dev/my_project
# :repositories:
#   - :name: Sproutcore
#     :path: frameworks/sproutcore
#   - :name: SCUI
#     :path: frameworks/scui

require 'yaml'
require 'fileutils'

# Grit Class
class Grit
  def help
    puts "OPTIONS:\n\n"
    puts "\thelp                         - display list of commands"
    puts "\tinit                         - create grit config.yml file in .grit dir"
    puts "\tadd-all                      - add all directories in the current directory to config.yml"
    puts "\tclean-config                 - remove any missing direcotries from config.yml"
    puts "\tadd-repository <name> <dir>  - add repo and dir to config.yml"
    puts "\tremove-repository <name>     - remove specified repo from config.yml"
    puts "\ton <repo> <action>           - execute git action on specific repo\n\n"
  end

  def initialize_grit(args)
    location = args[0] || Dir.pwd

    if File.directory?(location)
      directory = File.join(location, '.grit')
      FileUtils.mkdir(directory) unless File.directory?(directory)

      config_file = directory + '/config.yml'
      unless File.exist?(config_file)
        config = {}
        config[:root] ||= Dir.pwd
        config[:repositories] ||= [{ name: 'example_repo', path: 'example_repo' }]
        config[:ignore_root] = true

        File.open(directory + '/config.yml', 'w') { |f| YAML.dump(config, f) }
      end
    else
      puts "Directory doesn't exist!"
    end
  end

  def load_config
    File.open(File.join(FileUtils.pwd, '.grit/config.yml')) { |f| YAML.load(f) }
  end

  def write_config(config)
    File.open(File.join(FileUtils.pwd, '.grit/config.yml'), 'w') { |f| YAML.dump(config, f) }
  end

  def add_repository(args)
    config = load_config
    name = args[0]
    path = args[1] || args[0]

    config[:repositories] = [] if config[:repositories].nil?

    config[:repositories].push(name: name, path: path)
    write_config(config)
  end

  def add_all_repositories
    config = load_config

    directories = Dir.entries('.').select

    directories.each do |repo|
      next if repo == '.grit'

      git_dir = './' + repo + '/.git'
      next unless File.exist?(git_dir)

      puts "Adding #{repo}"
      config[:repositories].push(name: repo, path: repo)
    end
    write_config(config)
  end

  def clean_config
    config = load_config

    original_repositories = if config[:ignore_root]
                              config[:repositories]
                            else
                              config[:repositories].unshift(name: 'Root', path: config[:root])
                            end

    config[:repositories] = original_repositories.delete_if do |repo|
      git_dir = './' + repo[:path] + '/.git'
      true if repo[:path].nil? || !File.directory?(repo[:path]) || !File.exist?(git_dir)
    end
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
      puts "Can't find repository: #{repo_name}"
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
when 'help'
  project.help
when 'init'
  project.initialize_grit(ARGV[1..-1])
when 'add-repository'
  project.add_repository(ARGV[1..-1])
when 'add-all'
  project.add_all_repositories
when 'clean-config'
  project.clean_config
when 'remove-repository'
  project.remove_repository(ARGV[1..-1])
when 'on'
  project.perform_on(ARGV[1], ARGV[2..-1])
else
  project.proceed ARGV
end
