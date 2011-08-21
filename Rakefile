begin
  require 'rake/clean'
  require 'open-uri' 
  require 'archive'
rescue LoadError
  abort "Required gems missing. Try 'sudo gem install libarchive-ruby'."
end

# This rakefile is used to set up the working environment for the mutation 
# score predictor project. There are tasks to download and set up the required
# mutation testing tool Javalanche. Other tasks are present to aid the user in
# running the experiment.
#
# @author Kevin Jalbert
# @version 0.2.0

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/Desktop/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.1.0.v20100507.jar"
@eclipse_workspace = "/home/jalbert/workspace/"
@project_name = "joda-time"
@project_prefix = "org.joda.time"
@project_testsuite = "org.joda.time.TestAll"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@java_memory = "-Xmx1g"
@max_cores = "1"
@python = "python2" # Python 2.7 command
@classpath = nil  # Acquired through ant/maven extraction

# Variables related to setup and execution
@home = Dir.pwd
@eclipse_project_build = "#{@project_location}build.xml"
@eclipse_metric_plugin = "#{@eclipse}plugins/" \
                         "net.sourceforge.metrics_1.3.6"
@eclipse_metrics_xml_reader_git = "git://github.com/kevinjalbert/" \
                                  "eclipse_metrics_xml_reader.git"
@javalanche = "javalanche-0.3.6"
@javalanche_tar = "#{@javalanche}-bin.tar.gz"
@javalanche_download = "http://www.st.cs.uni-saarland.de/~schuler/" \
                       "javalanche/builds/#{@javalanche_tar}"
@javalanche_location = "#{@home}/#{@javalanche}"
@javalanche_project_file = "#{@project_location}javalanche.xml"

# Files to remove via clobbering them
CLOBBER.include("./#{@javalanche}")
CLOBBER.include("./eclipse_metrics_xml_reader")
CLEAN.include("./data")

task :default => :list

# Displays the available commands as well as required tools
task :list do
  sh "rake -T"
  puts "\nWork flow: 'install' -> 'setup_svm'"
  puts "'ant' and 'mvn' are required to use Javalanche"
  puts "'eclipse' is required to use Eclipse Metrics plugin"
  puts "'python' and 'git' are required to use eclipse_metrics_xml_reader"
end

desc "Install the necessary components for this project"
task :install => [:install_javalanche, :install_eclipse_metrics_xml_reader] do
  puts "Necessary components are present and ready"
end

# Install Javalanche
task :install_javalanche do

  # Perform install only if Javalanche directory doesn't exist
  if not File.directory?(@javalanche)
    
    # Download Javalanche's tar file
    puts "\nDirectory #{@javalanche} does not exists"
    puts "\nDownloading #{@javalanche_tar} (15.3 MB)"
    writeOut = open(@javalanche_tar, "wb")
    writeOut.write(open(@javalanche_download).read)
    writeOut.close

    # Extract all files to the current directory
    puts "\nExtracting #{@javalanche_tar}"
    a = Archive.new(@javalanche_tar)
    a.extract

    # Deleting Javalanche's tar file
    puts "\nDeleting #{@javalanche_tar}"
    rm @javalanche_tar

    # Create data directory to place misc data files
    mkdir "data"

  else
    puts "\nDirectory #{@javalanche} already exists"
  end
end

# Install Eclipse metrics XML reader
task :install_eclipse_metrics_xml_reader do

  # Perform install only if Javalanche directory doesn't exist
  if not File.directory?("eclipse_metrics_xml_reader")
    puts "\nCloning Eclipse metrics XML reader"
    sh "git clone #{@eclipse_metrics_xml_reader_git}"
  else
    puts "Directory eclipse_metrics_xml_reader already exists"
  end
end

# Set up support vector machine using the mutation scores and metrics
desc "Set up the support vector machine for training"
task :setup_svm => [:get_mutation_scores, :convert_metrics_to_libsvm] do

end

# Converts the metric XML file into a libsvm format
task :convert_metrics_to_libsvm => [:get_eclipse_metrics_xml, 
                                    :install_eclipse_metrics_xml_reader] do
    puts "Converting metrics to libsvm format"
    sh "#{@python} " \
       "./eclipse_metrics_xml_reader/src/eclipse_metrics_xml_reader.py -i " \
       "./data/#{@project_name}.xml"
end

# Executes the headless Eclipse Metrics plugin to acquire the metric XML file
task :get_eclipse_metrics_xml => :setup_metrics_build_file do

  # Make sure the Eclipse launcher exists
  if File.exists?(@eclipse_launcher)

    # Make sure the Eclipse metrics plugin exists
    if File.directory?(@eclipse_metric_plugin)

      # Make sure the eclipse project build file exists
      if File.exists?(@eclipse_project_build)

        # Execute the headless Eclipse command to export metrics of the project
        puts "Executing headless Eclipse Metrics plugin report export"
        sh "java #{@java_memory} -jar #{@eclipse_launcher} -noupdate " \
           "-application org.eclipse.ant.core.antRunner -data " \
           "#{@eclipse_workspace} -file #{@eclipse_project_build}"

        puts "If an error occurred make sure that the project was " \
             "successfully imported into Eclipse with no errors."
      else
        puts "ERROR: The #{@eclipse_project_build} file does not exist"
      end
    else
      puts "ERROR: The #{@eclipse_metric_plugin} directory does not exist"
    end
  else
    puts "ERROR: The #{@eclipse_launcher} file does not exist"
  end

  # Restore backup build file
  puts "Restoring project's original build file"
  FileUtils.rm(@eclipse_project_build)
  if File.exist?(@eclipse_project_build + ".backup")
    FileUtils.mv(@eclipse_project_build + ".backup", @eclipse_project_build)
  end
end

# Creates the build file needed to execute the headless Eclipse metrics plugin
task :setup_metrics_build_file do

  # Create a backup of the build file
  puts "Backing up project's build file"
  FileUtils.cp(@eclipse_project_build, @eclipse_project_build + ".backup")

  # Create new build file
  build_file = File.open(@eclipse_project_build, 'w')
  build_content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  build_content << "\n<project name=\"#{@project_name}\" default=\"metrics\"" \
                   " basedir=\".\">"
  build_content << "\n  <target name=\"metrics\">"
  build_content << "\n    <eclipse.refreshLocal " \
                   "resource=\"net.sourceforge.metrics\" depth=\"infinite\"/>"
  build_content << "\n    <metrics.enable " \
                   "projectName=\"net.sourceforge.metrics\"/>"
  build_content << "\n    <eclipse.build "
  build_content << "\n      ProjectName=\"#{@project_name}\" "
  build_content << "\n      BuildType=\"full\" "
  build_content << "\n      errorOut=\"errors.xml\" "
  build_content << "\n      errorFormat=\"xml\" "
  build_content << "\n      failOnError=\"true\"/>"
  build_content << "\n    <metrics.export "
  build_content << "\n      projectName=\"#{@project_name}\" "
  build_content << "\n      file=\"#{Dir.pwd}/data/#{@project_name}.xml\"/>"
  build_content << "\n  </target>"
  build_content << "\n</project>"  

  # Create a new build file with the new metrics task
  puts "Creating project's new build file"
  build_file = File.open(@eclipse_project_build, 'w')
  build_file.write(build_content)
  build_file.close
end

# Get the mutation scores for the project using javalanche
task :get_mutation_scores => [:install_javalanche, :setup_javalanche] do

  # Run javalanche
  Dir.chdir(@project_location) do
    puts "Executing Javalanche command"
    sh "#{create_javalanche_command}"
  end

  # Extract mutation scores from Javalanche

end

# Set up Javalanche 
task :setup_javalanche do

  # Find and set the classpath for the project
  puts "Finding classpath of the project"
  find_and_set_classpath

  # Read default javalanche.xml file in
  file = File.open("#{@javalanche}/javalanche.xml", 'r')
  content = file.read
  file.close 

  # Make new target
  content.gsub!("</project>", "")
  content << "    <target name=\"getMutationScores\" depends=\"startHsql,"
  content << "schemaexport,scanProject,scan,createTasks,createCoverageData,"
  content << "createMutationMakefile\">"
  content << "\n        <exec executable=\"make\" spawn=\"false\">"
  content << "\n            <arg value=\"-j#{@max_cores}\"/>"
  content << "\n        </exec>"
  content << "\n        <property name=\"javalanche.mutation.analyzers\" value"
  content << "=\"de.unisb.cs.st.javalanche.coverage.CoverageAnalyzer\" />"
  content << "\n        <antcall target=\"analyzeResults\" />"
  content << "\n        <antcall target=\"stopHsql\" />"
  content << "\n     </target>"
  content << "\n</project>"

  # Write new target to javalanche.xml within project directory
  puts "Created new javalanche.xml file in project directory"
  file = File.open("#{@project_location}javalanche.xml", 'w')
  file.write(content)
  file.close

  # Create the runMutations.sh script in the project directory
  content = "#!/bin/sh"
  content << "\nOUTPUTFILE=mutation-files/output-runMutation-${2}.txt"
  content << "\nBACKOUTPUTFILE=mutation-files/back-output-runMutation-${2}.txt"
  content << "\nif [ -e $OUTPUTFILE ]"
  content << "\nthen"
  content << "\n        mv $OUTPUTFILE ${BACKOUTPUTFILE}"
  content << "\nfi"
  content << "\nwhile  ! grep -q ALL_RESULTS ${OUTPUTFILE}"
  content << "\ndo"
  content << "\n        echo \"Task ${2} not completed - starting again\""
  content << "\n        nice -10 ant -f javalanche.xml " 
  content << "-Dprefix=#{@project_prefix} -Dcp=#{@classpath} " 
  content << "-Dtestsuite=#{@project_testsuite} " 
  content << "-Djavalanche=#{@javalanche_location} runMutationsCoverage ${3} " 
  content << "-Dmutation.file=${1}  2>&1 | tee -a $OUTPUTFILE"
  content << "\n        sleep 1"
  content << "\ndone"

  # Write runMutations.sh within project directory
  puts "Created runMutations.sh script in project directory"
  file = File.open("#{@project_location}runMutations.sh", 'w')
  file.chmod(0766)
  file.write(content)
  file.close
end

def create_javalanche_command  

    # Return command to execute Javalanche
    command = "ant -f javalanche.xml -Dprefix=#{@project_prefix} "
    command << "-Dcp=#{@classpath} -Dtestsuite=#{@project_testsuite} "
    command << "-Djavalanche=#{@javalanche_location} getMutationScores"
  return command
end

def find_and_set_classpath
  Dir.chdir(@project_location) do

    # Acquire classpath from 'ant test' or 'mvn test' command using a Regex
    if File.exists?("#{@project_location}build.xml")  # Ant build file
      output = `ant -v test`
      @classpath = output.scan(/-classpath'\s*\[junit\]\s*'(.*)'/)[0][0]
    elsif File.exists?("#{@project_location}pom.xml")  # Maven pom file
      puts "TODO: Maven classpath extraction is not done yet"
      output = `mvn -X test`
      # @classpath = output.scan()[0][0]
    end
  end
end
