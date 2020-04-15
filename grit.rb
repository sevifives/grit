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
# root: /Users/john/dev/my_project
# repositories:
#   - name: Sproutcore
#     path: frameworks/sproutcore
#   - name: SCUI
#     path: frameworks/scui

require 'yaml'
require 'fileutils'

# Grit Class
class Grit
  VERSION = '2020.4.15'

  def version
    VERSION
  end

  def help
    puts "OPTIONS:\n\n"
    puts "\thelp                         - display list of commands"
    puts "\tinit <dir> (optional)        - create grit config.yml file in .grit dir"
    puts "\tadd-all                      - add all directories in the current directory to config.yml"
    puts "\tconfig                       - show current config settings"
    puts "\tclean-config                 - remove any missing direcotries from config.yml"
    puts "\tconvert-config               - convert conf from sym to string"
    puts "\tadd-repository <name> <dir>  - add repo and dir to config.yml"
    puts "\tremove-repository <name>     - remove specified repo from config.yml"
    puts "\tdestroy                      - delete current grit setup including config and .grit directory"
    puts "\ton <repo> <action>           - execute git action on specific repo"
    puts "\tversion                      - get current grit version\n\n"
  end

  def initialize_grit(args)
    location = args[0] || Dir.pwd

    if File.directory?(location)
      directory = File.join(location, '.grit')
      FileUtils.mkdir(directory) unless File.directory?(directory)

      config_file = directory + '/config.yml'
      unless File.exist?(config_file)
        config = {}
        config['root'] ||= location
        config['repositories'] ||= [{ 'name' => 'example_repo', 'path' => 'example_repo' }]
        config['ignore_root'] = true

        File.open(directory + '/config.yml', 'w') { |f| YAML.dump(config, f) }
      end
    else
      puts "Directory doesn't exist!"
    end
  end

  def destroy(args)
    location = args[0] || Dir.pwd
    directory = File.join(location, '.grit')

    if File.directory?(directory)
      File.delete(directory + '/config.yml')
      Dir.delete(directory)
      puts "Grit configuration files have been removed from #{location}"
    else
      puts "#{location} is not a grit project!"
    end
  end

  def load_config
    config = File.open(File.join(FileUtils.pwd, '.grit/config.yml')) { |f| YAML.safe_load(f) }
    config['repositories'].unshift('name' => 'Root', 'path' => config['root']) unless config['ignore_root']
    config
  rescue Psych::DisallowedClass
    puts 'Could not load config.  Probably need to perform a `grit convert-config` to string names'
    exit 1
  end

  def write_config(config)
    File.open(File.join(FileUtils.pwd, '.grit/config.yml'), 'w') { |f| YAML.dump(config, f) }
  end

  def config
    config = load_config
    puts config.to_yaml
  end

  def convert_config
    original_config = File.read(File.join(FileUtils.pwd, '.grit/config.yml'))
    new_config = YAML.safe_load(original_config.gsub(':repositories:', 'repositories:')
                                               .gsub(':root:', 'root:')
                                               .gsub(':ignore_root:', 'ignore_root:')
                                               .gsub(':name:', 'name:')
                                               .gsub(':path:', 'path:'))
    new_config.to_yaml
    write_config(new_config)
  end

  def add_repository(args)
    config = load_config
    name = args[0]
    path = args[1] || args[0]

    git_dir = path + '/.git'
    if File.exist?(git_dir)
      config['repositories'] = [] if config['repositories'].nil?
      config['repositories'].push('name' => name, 'path' => path)
      write_config(config)
      puts "Added #{name} repo located #{path}"
    else
      puts "The provided path #{path} does not include a git repository."
    end
  end

  def add_all_repositories
    config = load_config

    directories = Dir.entries('.').select
    directories.each do |repo|
      next if repo == '.grit'

      git_dir = './' + repo + '/.git'
      next unless File.exist?(git_dir)

      puts "Adding #{repo}"
      config['repositories'].push('name' => repo, 'path' => repo)
    end
    write_config(config)
  end

  def clean_config
    config = load_config

    original_repositories = config['repositories']
    config['repositories'] = original_repositories.delete_if do |repo|
      git_dir = './' + repo['path'] + '/.git'
      true if repo['path'].nil? || !File.directory?(repo['path']) || !File.exist?(git_dir)
    end
    write_config(config)
  end

  def get_repository(name)
    config = load_config
    config['repositories'].detect { |f| f['name'] == name }
  end

  def perform_on(repo_name, args)
    repo = get_repository(repo_name)
    args = args.join(' ') unless args.class == String

    if repo.nil? || repo['path'].nil? || !File.exist?(repo['path'])
      puts "Can't find repository: #{repo_name}"
      abort
    end

    Dir.chdir(repo['path']) do |_d|
      perform(args, repo['name'])
    end
  end

  def remove_repository(name)
    config = load_config

    match = get_repository(name.to_s)
    if match.nil?
      puts 'Could not find repository'
    elsif config['repositories'].delete(match)
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

    to_do = args.map { |x| x.include?(' ') ? "\"#{x}\"" : x }.join(' ')

    config['repositories'].each do |repo|
      if repo['path'].nil? || !File.exist?(repo['path'])
        puts "Can't find repository: #{repo['path']}"
        next
      end

      Dir.chdir(repo['path']) do |_d|
        perform(to_do, repo['name'])
      end
    end
  end
end

grit = Grit.new
case ARGV[0]
when 'help'
  grit.help
when 'init'
  grit.initialize_grit(ARGV[1..-1])
when 'add-repository'
  grit.add_repository(ARGV[1..-1])
when 'add-all'
  grit.add_all_repositories
when 'config'
  grit.config
when 'clean-config'
  grit.clean_config
when 'convert-config'
  grit.convert_config
when 'destroy'
  grit.destroy(ARGV[1..-1])
when 'remove-repository'
  grit.remove_repository(ARGV[1])
when 'on'
  grit.perform_on(ARGV[1], ARGV[2..-1])
when /version|-v|--version/
  puts grit.version
else
  grit.proceed(ARGV)
end
