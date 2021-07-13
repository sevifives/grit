#!/usr/bin/env ruby

# Grit is a way to manage multiple repos in a git repository seamlessly
# using the git CL tool
# It serves 'only' to be a mapping tool; it doesn't create/delete repositories
# only .grit/config.yml

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

      add_profile("config")
      set_profile("config")
    else
      puts "Directory doesn't exist!"
    end
  end

  def get_config(profile=nil)
    profile = get_current_profile if profile == nil
    f = ".grit/#{profile}.yml" % {:profile => profile}
    return open(File.join(FileUtils.pwd,f)) {|f| YAML.load(f)}
  end

  def write_config (config, profile = nil)
    profile = get_current_profile if profile == nil
    f = ".grit/#{profile}.yml" % {:profile => profile}
    return open(File.join(FileUtils.pwd,f),'w') {|f| YAML.dump(config,f)}
  end

  def add_profile (profile = nil, root = nil)
    return if profile == nil

    location = Dir.pwd
    directory = File.join(location,'.grit')

    file = profile + ".yml"
    config_file = directory+'/'+file
    if !File.exists?(config_file)
      config = {}
      config[:root] ||= ((root == nil || root.empty?) ? Dir.pwd : root)
      config[:repositories] ||= []

      open(config_file,'w') {|f| YAML.dump(config,f)}
    end
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
    args = args.join(' ') unless args.class == String

    if repo.nil? || repo[:path].nil? || !File.exists?(repo[:path])
      puts "Can't find repository: #{repo_name} at location #{repo[:path]}"
      abort
    end

    Dir.chdir(repo[:path]) do |d|
      perform(args,repo[:name])
    end
  end

  def set_profile(profile = "config")
    profile = "config" if (profile == nil || profile.empty?)
    location = Dir.pwd
    f = File.new(".grit/current_profile", 'w')
    f.write(profile)
    f.close
  end

  def get_current_profile
    location = Dir.pwd
    if (!File.exists?(".grit/current_profile")) {
      return File.read(".grit/current_profile")  
    }
    return "config"
  end

  # opting to not remove the directory
  def remove_repository (names)
    config = get_config
    puts config.inspect

    match = get_repository(names[0])
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

  def perform (to_do,name)
    puts "-"*80
    puts "# #{name.upcase} -- git #{to_do}" unless name.nil?
    puts `git #{to_do}`
    puts "-"*80
    puts ""
  end

  def proceed (args)
    config = get_config
    repositories = config[:repositories].unshift({:name => 'Root',:path => config[:root]})

    to_do = args.map{|x| if x.include?(" "); "\"#{x}\""; else; x; end}.join(" ")

    repositories.each do |repo|
      if repo[:path].nil?
        puts "Can't find repository: #{repo[:path]}"
        continue
      end

      Dir.chdir(repo[:path]) do |d|
         perform(to_do,repo[:name])
      end
    end
  end
end


# TODO ... this better
project = Grit.new
case ARGV[0]
when 'init'
  project.initialize_grit(ARGV[1..-1])
when 'ar','add-repository'
  project.add_repository(ARGV[1..-1])
when 'rr','remove-repository'
  project.remove_repository(ARGV[1..-1])
when 'ap','add-profile'
  project.add_profile(ARGV[1], ARGV[2])
when 'sp','set-profile'
  project.set_profile(ARGV[1])
when 'wp','which-profile'
  puts project.get_current_profile
when 'on'
  project.perform_on(ARGV[1],ARGV[2..-1])
else
  project.proceed ARGV
end
