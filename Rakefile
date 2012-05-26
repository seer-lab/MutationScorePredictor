begin
  require "rake/clean"
  require "open-uri"
  require "archive"
  require "nokogiri"
  require "data_mapper"
  require "awesome_print"
  require "statsample"
  Dir.glob(File.dirname(__FILE__) + '/lib/rake_tasks/*.rb') {|file| require file}
  Dir.glob(File.dirname(__FILE__) + '/lib/*.rb') {|file| require file}
rescue LoadError => e
  puts e
  abort "Gems missing. Try use `bundle install`."
end

# This rakefile is used to set up the working environment for the mutation
# score predictor project. There are tasks to download and set up the required
# mutation testing tool Javalanche. Other tasks are present to aid the user in
# running the experiment. (All the tasks are located in /lib/rake_tasks/)
#
# @author Kevin Jalbert
# @version 0.8.0

task :default => :list

# Displays the available commands as well as required tools
task :list do
  sh "#{@rake} -T"
  puts "\nWork flow: 'install' -> 'setup_svm' -> 'cross_validation'"
  puts "Consult README.md for additional details and requirements"
  puts "Project being used must be imported in Eclipse (with metrics enabled)"
end

# Cleans the project and any generated files from the execution
task :clean => :clean_project do
end

# Cleans the project and all files not included in initial repository
task :clobber => :clean_project do
end

# Calls the clean commands on the project, as well as removing produced files
task :clean_project do
  Dir.chdir("#{@project_location}") do

    # Only clean Javalanche if the javalanche.xml is in the project directory
    if File.exists?("javalanche.xml")
      sh "#{create_javalanche_command("startHsql")}"
      sh "#{create_javalanche_command("deleteResults")}"
      sh "#{create_javalanche_command("deleteMutations")}"
      sh "#{create_javalanche_command("cleanJavalanche")}"
      sh "#{create_javalanche_command("stopHsql")}"
    end
      rm_f("javalanche.xml")
      rm_f("Makefile")
      rm_f("runMutations.sh")
      rm_f("analyze.csv")
  end
end

def find_and_set_classpath
  puts "[LOG] Acquiring classpath of project by running ant/maven 'clean' then 'test' tasks"
  Dir.chdir(@project_location) do
    if @project_builder == "ant"
      `ant clean`
      output = `ant -v test`

      # Take the longest classpath (the correct one)
      output.scan(/-classpath'\s*\[junit\]\s*'(.*)'/).each do |match|
        @classpath = match[0] if match[0].length > @classpath.length
      end
    elsif @project_builder == "maven"
      `mvn clean`
      output = `mvn -X test`

      # Take the longest classpath (the correct one)
      output.scan(/-classpath\s(.*?)\s/).each do |match|
        @classpath = match[0] if match[0].length > @classpath.length
      end
    else
      puts "[WARN] Using @classpath specified in Rakefile"
    end
  end
end

def number_of_tasks

  # Make sure there exists enough memory for the tests to complete
  if @memory_for_tests.to_i > @max_memory.to_i
    raise("[ERROR] Not enough memory to execute test suite successfully")
  end

  # Figure out the number of task that can be ran reliably given the max memory
  task = @max_memory.to_i / @memory_for_tests.to_i

  # Ensure that the number of tasks is less then the number of cores avalible
  if task > @max_cores.to_i
    task = @max_cores.to_i
  end

  return task.to_s
end
