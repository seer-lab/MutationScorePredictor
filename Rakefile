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
# @version 0.4.0

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/Desktop/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.1.0.v20100507.jar"
@eclipse_workspace = "/home/jalbert/workspace/"
@project_name = "joda-time-2.0"
@project_prefix = "org.joda.time"
@project_testsuite = "org.joda.time.TestAll"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@java_memory = "-Xmx1g"
@max_cores = "1"
@python = "python2"  # Python 2.7 command
@ruby = "ruby"  # Ruby command
@rake = "rake"  # Rake command
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
@libsvm = "libsvm-3.1"
@libsvm_tar = "libsvm-3.1.tar.gz"
@libsvm_download = "http://www.csie.ntu.edu.tw/~cjlin/libsvm/libsvm-3.1.tar.gz"
@cross_validation_folds = 10

# Files to remove via clobbering them
CLOBBER.include("./#{@javalanche}")
CLOBBER.include("./eclipse_metrics_xml_reader")
CLOBBER.include("./#{@libsvm}")
CLEAN.include("./data")
CLEAN.include("./#{@javalanche}")
CLEAN.include("./eclipse_metrics_xml_reader")
CLEAN.include("./#{@libsvm}")
CLEAN.include("analyze.csv")
CLEAN.include("javalanche.xml")
CLEAN.include("Makefile")
CLEAN.include("runMutations.sh")

task :default => :list

# Displays the available commands as well as required tools
task :list do
  sh "#{@rake} -T"
  puts "\nWork flow: 'install' -> 'setup_svm' -> 'cross_validation'"
  puts "'ant' and 'mvn' are required to use Javalanche"
  puts "'eclipse' is required to use Eclipse Metrics plugin"
  puts "'python' and 'git' are required to use eclipse_metrics_xml_reader"
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
    sh "#{create_javalanche_command("deleteResults")}"
    sh "#{create_javalanche_command("deleteMutations")}"
    sh "#{create_javalanche_command("cleanJavalanche")}"
    rm_f("analyze.csv")
    rm_f("javalanche.xml")
    rm_f("Makefile")
    rm_f("runMutations.sh")
  end
end

desc "Install the necessary components for this project"
task :install => [:install_javalanche, :install_eclipse_metrics_xml_reader,
                  :install_libsvm] do
  puts "Necessary components are present and ready"
end

# Install Javalanche
task :install_javalanche do

  # Perform install only if Javalanche directory doesn't exist
  if not File.directory?(@javalanche)
    
    # Download Javalanche's tar file
    puts "[LOG] Directory #{@javalanche} does not exists"
    puts "[LOG] Downloading #{@javalanche_tar} (15.3 MB)"
    writeOut = open(@javalanche_tar, "wb")
    writeOut.write(open(@javalanche_download).read)
    writeOut.close

    # Extract all files to the current directory
    puts "[LOG] Extracting #{@javalanche_tar}"
    a = Archive.new(@javalanche_tar)
    a.extract

    # Deleting Javalanche's tar file
    puts "[LOG] Deleting #{@javalanche_tar}"
    rm @javalanche_tar

    # Create data directory to place misc data files
    if not File.directory?("data")
      mkdir "data"
    end

  else
    puts "[LOG] Directory #{@javalanche} already exists"
  end
end

# Install Eclipse metrics XML reader
task :install_eclipse_metrics_xml_reader do

  # Perform install only if Javalanche directory doesn't exist
  if not File.directory?("eclipse_metrics_xml_reader")
    puts "[LOG] Cloning Eclipse metrics XML reader"
    sh "git clone #{@eclipse_metrics_xml_reader_git}"
  else
    puts "[LOG] Directory eclipse_metrics_xml_reader already exists"
  end

  # Create data directory to place misc data files
  if not File.directory?("data")
    mkdir "data"
  end
end

# Install libsvm
task :install_libsvm do
  # Perform install only if libsvm directory doesn't exist
  if not File.directory?(@libsvm)
    
    # Download libsvm's tar file
    puts "[LOG] Directory #{@libsvm} does not exists"
    puts "[LOG] Downloading #{@libsvm_tar} (599.6 KB)"
    writeOut = open(@libsvm_tar, "wb")
    writeOut.write(open(@libsvm_download).read)
    writeOut.close

    # Extract all files to the current directory
    puts "[LOG] Extracting #{@libsvm_tar}"
    a = Archive.new(@libsvm_tar)
    a.extract

    # Deleting libsvm's tar file
    puts "[LOG] Deleting #{@libsvm_tar}"
    rm @libsvm_tar

  else
    puts "[LOG] Directory #{@libsvm} already exists"
  end
end

# Set up support vector machine using the mutation scores and metrics
desc "Set up the support vector machine for training"
task :setup_svm => [:get_mutation_scores, :convert_metrics_to_libsvm] do
  
  # Add test metrics to the methods's metrics
  puts "[LOG] Adding testing metrics to method metrics"
  sh "#{@ruby} " \
     "./test_suite_method_metrics.rb #{@project_location} " \
     "./data/#{@project_name}_method.labels " \
     "./data/#{@project_name}_method.libsvm"

  # Synthesis the libsvm and the mutation scores into known libsvm data
  puts "[LOG] Synthesizing metrics and mutation scores to a trainable libsvm"
  sh "#{@ruby} metric_libsvm_synthesizer.rb " \
     "./data/#{@project_name}_class.libsvm " \
     "./data/#{@project_name}_class.labels " \
     "./data/#{@project_name}_class_mutation.score"
  sh "#{@ruby} metric_libsvm_synthesizer.rb " \
     "./data/#{@project_name}_method.libsvm " \
     "./data/#{@project_name}_method.labels " \
     "./data/#{@project_name}_method_mutation.score"
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation  do

  Dir.chdir("#{@libsvm}") do
    puts "[LOG] Making libsvm"
    sh "make"
    Dir.chdir("tools") do

      puts "[LOG] Modifying grid.py to use #{@max_cores} cores and " \
           "#{@cross_validation_folds} folds"
      file = File.open("grid.py", 'r')
      content = file.read
      file.close 

      content.gsub!("nr_local_worker = 1", "nr_local_worker = #{@max_cores}")
      content.gsub!("fold = 5", "fold = #{@cross_validation_folds}")

      file = File.open("grid.py", 'w')
      file.write(content)
      file.close

      puts "[LOG] Performing cross validation"
      sh "#{@python} easy.py ./../../data/#{@project_name}_class.libsvm_synth"
      sh "#{@python} easy.py ./../../data/#{@project_name}_method.libsvm_synth"
    end
  end
end

# Converts the metric XML file into a libsvm format
task :convert_metrics_to_libsvm => [:get_eclipse_metrics_xml, 
                                    :install_eclipse_metrics_xml_reader] do
    puts "[LOG] Converting metrics to libsvm format"
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
        puts "[LOG] Executing headless Eclipse Metrics plugin report export"
        
        begin
          sh "java #{@java_memory} -jar #{@eclipse_launcher} -noupdate " \
             "-application org.eclipse.ant.core.antRunner -data " \
             "#{@eclipse_workspace} -file #{@eclipse_project_build}"
        rescue Exception=>e
          # Restore backup build file
          puts "[LOG] Restoring project's original build file"
          FileUtils.rm(@eclipse_project_build)
          if File.exist?(@eclipse_project_build + ".backup")
            FileUtils.mv(@eclipse_project_build + ".backup", @eclipse_project_build)
          end
          puts "[LOG] If an error occurred make sure that the project was " \
               "successfully imported into Eclipse with no errors."
          abort("[ERROR] Problem with Eclipse Project's setup")
        end
      else
        puts "[ERROR] The #{@eclipse_project_build} file does not exist"
      end
    else
      puts "[ERROR] The #{@eclipse_metric_plugin} directory does not exist"
    end
  else
    puts "[ERROR] The #{@eclipse_launcher} file does not exist"
  end

  # Restore backup build file
  puts "[LOG] Restoring project's original build file"
  FileUtils.rm(@eclipse_project_build)
  if File.exist?(@eclipse_project_build + ".backup")
    FileUtils.mv(@eclipse_project_build + ".backup", @eclipse_project_build)
  end
end

# Creates the build file needed to execute the headless Eclipse metrics plugin
task :setup_metrics_build_file do

  # Create a backup of the build file
  puts "[LOG] Backing up project's build file"
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
  puts "[LOG] Creating project's new build file"
  build_file = File.open(@eclipse_project_build, 'w')
  build_file.write(build_content)
  build_file.close
end

# Get the mutation scores for the project using javalanche
task :get_mutation_scores => [:install_javalanche, :setup_javalanche] do

  # Run javalanche
  Dir.chdir(@project_location) do
    puts "[LOG] Executing Javalanche command"
    sh "#{create_javalanche_command("getMutationScores")}"
  end

  # Extract mutation scores from Javalanche
  puts "[LOG] Extracting mutation scores from Javalanche results"
  sh "#{@ruby} mutation_scorer.rb #{@project_name} " \
     "#{@project_location}analyze.csv"
  mv("#{@project_name}_class_mutation.score", "./data/")
  mv("#{@project_name}_method_mutation.score", "./data/")
  mv("#{@project_name}_mutation.operators", "./data/")
end

# Set up Javalanche 
task :setup_javalanche do

  # Find and set the classpath for the project
  puts "[LOG] Finding classpath of the project"
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
  puts "[LOG] Created new javalanche.xml file in project directory"
  file = File.open("#{@project_location}javalanche.xml", 'w')
  file.write(content)
  file.close

  # Read log4j property file
  file = File.open("#{@javalanche}/src/main/resources/log4j.properties", 'r')
  content = file.read
  file.close 

  # Adjust log4j reporting level from WARN to INFO (needed for later step)
  content.gsub!("log4j.rootCategory=WARN", "log4j.rootCategory=INFO")

  # Overwrite the log4j file with the new content
  puts "[LOG] Adjusting log4j's reporting level to INFO"
  file = File.open("#{@javalanche}/src/main/resources/log4j.properties", 'w')
  file.write(content)
  file.close

  # Read hibernate.cfg property file
  file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'r')
  content = file.read
  file.close 

  # Adjust hibernate.cfg idle test time (try to avoid possible deadlock error)
  content.gsub!("\"hibernate.c3p0.idle_test_period\">3000", 
                "\"hibernate.c3p0.idle_test_period\">300")

  # Overwrite the hibernate.cfg file with the new content
  puts "[LOG] Adjusting hibernate.cfg idle test time to 300"
  file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'w')
  file.write(content)
  file.close

  # Create the runMutations.sh script in the project directory
  content = "#!/bin/sh"
  content << "\nOUTPUTFILE=mutation-files/output-runMutation-${2}.txt"
  content << "\nBACKOUTPUTFILE=mutation-files/back-output-${2}.txt"
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
  content << "-Djavalanche=#{@javalanche_location} "
  content << "-Djavalanche.properties.add="
  content << "-Djavalanche.stop.after.first.fail=false runMutationsCoverage " 
  content << "${3} -Dmutation.file=${1}  2>&1 | tee -a $OUTPUTFILE"
  content << "\n        sleep 1"
  content << "\ndone"

  # Write runMutations.sh within project directory
  puts "[LOG] Created runMutations.sh script in project directory"
  file = File.open("#{@project_location}runMutations.sh", 'w')
  file.chmod(0766)
  file.write(content)
  file.close
end

def create_javalanche_command(task)
    command = "ant -f javalanche.xml -Dprefix=#{@project_prefix} "
    command << "-Dcp=#{@classpath} -Dtestsuite=#{@project_testsuite} "
    command << "-Djavalanche=#{@javalanche_location} #{task}"
  return command
end

def find_and_set_classpath
  puts "[LOG] Acquiring classpath of project by running ant/maven 'test' task"
  Dir.chdir(@project_location) do
    # Acquire classpath from 'ant test' or 'mvn test' command using a Regex
    if File.exists?("#{@project_location}build.xml")  # Ant build file
      output = `ant -v test`
      @classpath = output.scan(/-classpath'\s*\[junit\]\s*'(.*)'/)[0][0]
    elsif File.exists?("#{@project_location}pom.xml")  # Maven pom file
      puts "[TODO] Maven classpath extraction is not done yet"
      output = `mvn -X test`
      # @classpath = output.scan()[0][0]
    end
  end
end
