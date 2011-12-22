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

  def proceed (args)
    config = open(File.join(FileUtils.pwd,'.grit/config.yml')) {|f| YAML.load(f) }
    repositories = config[:repositories].unshift({:name => 'Root',:path => config[:root]})

    to_do = args.join(' ')
    repositories.each do |repo|
      puts "Performing operation #{to_do} on #{repo[:name]}"
      raise "Shit!" if repo[:path].nil?
      Dir.chdir(repo[:path]) do |d|
        puts `git #{to_do}`
      end
    end
  end
end


project = Grit.new
if ARGV[0] === 'init'
  project.initialize_grit(ARGV[1..-1])
else
  project.proceed ARGV
end