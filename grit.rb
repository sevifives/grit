#!/usr/bin/env ruby

# Grit is a way to manage multiple repos in a git repository seamlessly
# using the git CL tool

# What Grit should do:
# - Proxy the git API
# - Don't get in the way
# - Allow the user to make the normal git choices due to that proxy
# - Not require a bunch of retarded crap like Google's git-repo to get started

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

class Grit
  def initialize_grit (args)
    location = args[0] || Dir.pwd

    if File.directory?(location)
      directory = File.join(location,'.grit')
      FileUtils.mkdir(directory) unless File.directory?(directory)

      config_file = directory+'/config.yml'
      if !File.exists?(config_file)
        config = {}
        config[:root] ||= Dir.pwd
        config[:repositories] ||= []

        open(directory+'/config.yml','w') {|f| YAML.dump(config,f)}
      end
    else
      puts "Directory doesn't exist!"
    end
  end

  def get_config
    return open(File.join(FileUtils.pwd,'.grit/config.yml')) {|f| YAML.load(f)}
  end

  def write_config (config)
    return open(File.join(FileUtils.pwd,'.grit/config.yml'),'w') {|f| YAML.dump(config,f)}
  end

  def add_repository (args)
    config = get_config
    name,path = args[0],args[1]

    config[:repositories].push({:name => name, :path => path})
    self.write_config(config)
  end

  def get_repository(name)
    config = get_config
    return config[:repositories].detect{|f| f[:name] == name}
  end

  def perform_on (repo_name,args)
    repo = get_repository(repo_name)

  end

  def remove_repository (names)
    config = get_config
    puts config.inspect

    match = config[:repositories].detect{|f| f[:name] == name}
    puts match.inspect
    unless match.nil?
      if config[:repositories].delete(match)
        write_config(config)
        puts "Removed repository #{name} from grit"
      else
        puts "Unable to remove repository #{name}"
      end
    else
      puts "Could not find repository"
    end
  end

  def perform (to_do)
    puts `git #{to_do}`
  end

  def proceed (args)
    config = get_config
    repositories = config[:repositories].unshift({:name => 'Root',:path => config[:root]})

    to_do = args.join(' ')
    repositories.each do |repo|
      puts "Performing operation #{to_do} on #{repo[:name]}"
      raise "Shit!" if repo[:path].nil?
      Dir.chdir(repo[:path]) do |d|
         perform(to_do)
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
  project.perform_on(ARG[1],ARGV[2..-1])
else
  project.proceed ARGV
end