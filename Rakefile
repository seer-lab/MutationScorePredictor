begin
  require 'rake/clean'
  require 'open-uri'
  require 'archive'
  require 'nokogiri'
  require './mutation_scorer.rb'
  require './metric_libsvm_synthesizer.rb'
  require './test_suite_method_metrics.rb'
  require './class_metric_accumulator.rb'
rescue LoadError
  abort "Gems missing. Try 'sudo gem install nokogiri libarchive-ruby'."
end

# This rakefile is used to set up the working environment for the mutation 
# score predictor project. There are tasks to download and set up the required
# mutation testing tool Javalanche. Other tasks are present to aid the user in
# running the experiment.
#
# @author Kevin Jalbert
# @version 0.6.0

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/Desktop/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.1.0.v20100507.jar"
@eclipse_workspace = "/home/jalbert/workspace/"
@project_name = "joda-time-2.0"
@project_prefix = "org.joda.time"
@project_testsuite = "org.joda.time.TestAll"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@max_memory = "3500"  # In megabytes (the max avalible memory)
@memory_for_tests = "1750"  # In megabytes (the memory needed for the test suite)
@project_test_directory = "#{@project_location}src/test/"  # Then prefix occurs
@max_cores = "4"
@python = "python2"  # Python 2.7 command
@rake = "rake"  # Rake command
@classpath = nil  # Acquired through ant/maven extraction

# Variables related to Javalanche's database usage
@use_mysql = true
@mysql_database = "mutation_test"
@mysql_user = "root"
@mysql_password = "root"

# Variables related to setup and execution
@home = Dir.pwd
@eclipse_project_build = "#{@project_location}build.xml"
@eclipse_metric_plugin = "#{@eclipse}plugins/" \
                         "net.sourceforge.metrics_1.3.8.20100730-001.jar"
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
@emma = "emma-2.0.5312"
@emma_zip = "#{@emma}.zip"
@emma_download = "http://sourceforge.net/projects/emma/files/emma-release/" \
                 "2.0.5312/emma-2.0.5312.zip/download"
@junit_download = "http://sourceforge.net/projects/junit/files/junit/4.8.1/" \
                  "junit-4.8.1.jar/download"
@junit_jar = "junit-4.8.1.jar"

# Files to remove via clobbering them
CLOBBER.include("./#{@javalanche}")
CLOBBER.include("./eclipse_metrics_xml_reader")
CLOBBER.include("./#{@libsvm}")
CLOBBER.include("./#{@emma}")
CLOBBER.include("./#{@junit_jar}")
CLEAN.include("./data")
CLEAN.include("analyze.csv")
CLEAN.include("javalanche.xml")
CLEAN.include("Makefile")
CLEAN.include("runMutations.sh")

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
      if @use_mysql 
        sh "#{create_javalanche_command("startHsql")}"
      end
      sh "#{create_javalanche_command("deleteResults")}"
      sh "#{create_javalanche_command("deleteMutations")}"
      sh "#{create_javalanche_command("cleanJavalanche")}"
      if @use_mysql
        sh "#{create_javalanche_command("stopHsql")}"
      end
    end
      rm_f("analyze.csv")
      rm_f("javalanche.xml")
      rm_f("Makefile")
      rm_f("runMutations.sh")
  end
end

desc "Install the necessary components for this project"
task :install => [:install_javalanche, :install_eclipse_metrics_xml_reader,
                  :install_libsvm, :install_emma, :install_junit] do
  puts "[LOG] Necessary components are present and ready"
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

    # Adjust log4j reporting level from WARN to INFO (needed for later step)
    puts "[LOG] Adjusting log4j's reporting level to INFO"
    file = File.open("#{@javalanche}/src/main/resources/log4j.properties", 'r')
    content = file.read
    file.close
    content.gsub!("log4j.rootCategory=WARN", "log4j.rootCategory=INFO")
    file = File.open("#{@javalanche}/src/main/resources/log4j.properties", 'w')
    file.write(content)
    file.close

    # Adjust hibernate.cfg idle test time (try to avoid possible deadlock error)
    puts "[LOG] Adjusting hibernate.cfg idle test time to 300"
    file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'r')
    content = file.read
    file.close
    content.sub!("\"hibernate.c3p0.idle_test_period\">3000",
                 "\"hibernate.c3p0.idle_test_period\">300")

    # Configure the usage of Javalanche's database
    if @use_mysql
      puts "[LOG] Adjusting hibernate.cfg to use MySQL instead of HSQLDB"
      content.sub!("<!--", "")
      content.sub!("-->", "<!--")
      content.sub!("<property name=\"hibernate.jdbc.batch_size\">1</property>",
                   "<property name=\"hibernate.jdbc.batch_size\">1</property>-->")
      content.sub!("jdbc:mysql://localhost:3308/mutation_test",
                   "jdbc:mysql://localhost:3306/#{@mysql_database}")
      content.sub!("<property name=\"hibernate.connection.username\">mutation",
                   "<property name=\"hibernate.connection.username\">#{@mysql_user}")
      content.sub!("<property name=\"hibernate.connection.password\">mu",
                   "<property name=\"hibernate.connection.password\">#{@mysql_password}")
    end
    file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'w')
    file.write(content)
    file.close

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

# Install emma
task :install_emma do

  # Perform install only if emma directory doesn't exist
  if not File.directory?(@emma)
    
    # Download emma's zip file
    puts "[LOG] Directory #{@emma} does not exists"
    puts "[LOG] Downloading #{@emma_zip} (675.8 KB)"
    writeOut = open(@emma_zip, "wb")
    writeOut.write(open(@emma_download).read)
    writeOut.close

    # Extract all files to the current directory
    puts "[LOG] Extracting #{@emma_zip}"
    a = Archive.new(@emma_zip)
    a.extract

    # Deleting emma's zip file
    puts "[LOG] Deleting #{@emma_zip}"
    rm @emma_zip
  else
    puts "[LOG] Directory #{@emma} already exists"
  end
end

# Install junit jar
task :install_junit do

  # Perform install only if junit jar doesn't exist
  if not File.exists?(@junit_jar)

    # Download junit's jar file
    puts "[LOG] File #{@junit_jar} does not exists"
    puts "[LOG] Downloading #{@junit_jar} (231.5 KB)"
    writeOut = open(@junit_jar, "wb")
    writeOut.write(open(@junit_download).read)
    writeOut.close
  else
    puts "[LOG] File #{@junit_jar} already exists"
  end
end

# Set up support vector machine using the mutation scores and metrics
desc "Set up the support vector machine for training"
task :setup_svm => [:get_mutation_scores, :convert_metrics_to_libsvm,
                    :install_emma] do

  # Set up the process to find the test suite method metrics
  test_suite_method_metrics = TestSuiteMethodMetrics.new(@project_location,
                             "./data/#{@project_name}_method.labels",
                             "./data/#{@project_name}_method.libsvm")
  tests_for_methods = test_suite_method_metrics.get_tests_for_methods(
                        "#{@project_location}mutation-files/")

  # Run emma for each method using the touched tests, to get coverage metrics
  c = 1
  done = Hash.new
  Dir.chdir(@project_location) do

    # Format tests from array to string with no methods
    tests_for_methods.each do |method,tests|
      testing = ""

      # Filter the test methods to only test classes
      test_classes = []
      tests_for_methods[method].each do |test|
        test_classes << test[0, test.rindex(".")]
      end

      # Build string of testing concrete tests, while ignoring abstract tests
      test_classes.uniq.each do |test|
        
        # Acquire the actual file path of the test
        file = "#{@project_test_directory}#{test.gsub(".",File::Separator)}.java"

        # Seems that tests with the '$' still works via a system call (it will
        #   actually ignore everything after the '$' till the '.')
        # Check to see if the file is an abstract class, we'll ignore these
        if system("egrep abstract\\\s+class #{file}")
          puts "[INFO] Ignoring abstract test case #{test}"
          next
        end
        testing += test + " "
      end

      # Only execute the coverage test if it hasn't already been executed
      if done.has_key?(testing)
        puts "[LOG] Test coverage already executed, copying old results"
        cp("#{@home}/data/#{done[testing]}", "#{@home}/data/coverage#{c}.xml")
      else
        emma = "-cp #{@home}/#{@emma}/lib/emma.jar emmarun -r xml"
        opts = "-Dreport.sort=-method -Dverbosity.level=silent " \
              "-Dreport.columns=name,line,block -Dreport.depth=method " \
              "-Dreport.xml.out.file=coverage#{c}.xml " \
              "-ix +#{@project_prefix}.* "
        command = "java -Xmx#{@max_memory}m #{emma} -cp #{@classpath}:" \
                  "#{@home}/#{@junit_jar} #{opts}"
                
        # Store the output of the JUnit tests
        output = `#{command} org.junit.runner.JUnitCore #{testing}`

        # Handle output, it might have errors, nothing or results
        if output.include?("FAILURES!!!")
          puts "[ERROR] With Emma JUnit testing"
          file = File.open("#{@home}/data/coverage#{c}.xml", 'w')
          file.write("")
          file.close
        elsif testing == ""
          puts "[WARNING] No valid test cases to use with Emma"
          file = File.open("#{@home}/data/coverage#{c}.xml", 'w')
          file.write("")
          file.close
        else
          mv("coverage#{c}.xml", "#{@home}/data/")
        end

        # Store this test coverage to reduce number of executions
        done[testing] = "coverage#{c}.xml"
      end
      c += 1
    end
  end

  # Add test metrics to the methods's metrics
  puts "[LOG] Adding testing metrics to method metrics"
  test_suite_method_metrics.process(tests_for_methods)

  # Accumulating metrics from methods into the classes
  puts "[LOG] Accumulating metrics from methods into classes"
  ClassMetricAccumulator.new("./data/#{@project_name}_method.libsvm_new",
                           "./data/#{@project_name}_method.labels_new",
                           "./data/#{@project_name}_class.libsvm",
                           "./data/#{@project_name}_class.labels").process

  # Synthesize the libsvm and the mutation scores into known libsvm data
  puts "[LOG] Synthesizing metrics and mutation scores to a trainable libsvm"
  MetricLibsvmSynthesizer.new("./data/#{@project_name}_class.libsvm_new",
                              "./data/#{@project_name}_class.labels_new",
                              "./data/#{@project_name}_class_mutation.score").process
  MetricLibsvmSynthesizer.new("./data/#{@project_name}_method.libsvm_new",
                              "./data/#{@project_name}_method.labels_new",
                              "./data/#{@project_name}_method_mutation.score").process

  # Recap on the memory and cores used
  puts "Resource Summary:"
  puts "  Used #{number_of_tasks} tasks for mutation testing"
  puts "  Used #{@memory_for_tests}m memory for mutation testing tasks"
  puts "  Used #{@max_memory}m memory for Emma coverage"
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

      # Modify the settings to use the specified cores and folds
      file = File.open("grid.py", 'r')
      content = file.read
      file.close
      content.gsub!("nr_local_worker = 1", "nr_local_worker = #{@max_cores}")
      content.gsub!("fold = 5", "fold = #{@cross_validation_folds}")
      file = File.open("grid.py", 'w')
      file.write(content)
      file.close

      puts "[LOG] Performing cross validation"
      sh "#{@python} easy.py " \
         "./../../data/#{@project_name}_class.libsvm_new_synth"
      sh "#{@python} easy.py " \
         "./../../data/#{@project_name}_method.libsvm_new_synth"
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
  if File.exists?(@eclipse_launcher)
    if File.exists?(@eclipse_metric_plugin)
      if File.exists?(@eclipse_project_build)

        # Execute the headless Eclipse command to export metrics of the project
        puts "[LOG] Executing headless Eclipse Metrics plugin report export"

        begin
          sh "java -Xmx#{@max_memory}m -jar #{@eclipse_launcher} -noupdate " \
             "-application org.eclipse.ant.core.antRunner -data " \
             "#{@eclipse_workspace} -file #{@eclipse_project_build}"
        rescue Exception=>e
          # Restore backup build file
          puts "[LOG] Restoring project's original build file"
          FileUtils.rm(@eclipse_project_build)
          if File.exist?(@eclipse_project_build + ".backup")
            FileUtils.mv(@eclipse_project_build + ".backup",
                         @eclipse_project_build)
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
  MutationScorer.new(@project_name, "#{@project_location}analyze.csv").process
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
  content << "    <target name=\"getMutationScores\" depends=\""
  if !@use_mysql
    content << "startHsql,"
  end
  content << "schemaexport,scanProject,scan,createTasks,createCoverageData,"
  content << "createMutationMakefile\">"
  content << "\n        <exec executable=\"make\" spawn=\"false\">"
  content << "\n            <arg value=\"-j#{number_of_tasks}\"/>"
  content << "\n        </exec>"
  content << "\n        <property name=\"javalanche.mutation.analyzers\" value"
  content << "=\"de.unisb.cs.st.javalanche.coverage.CoverageAnalyzer\" />"
  content << "\n        <antcall target=\"analyzeResults\" />"
  if !@use_mysql
    content << "\n        <antcall target=\"stopHsql\" />"
  end
  content << "\n     </target>"
  content << "\n</project>"

  # Write new target to javalanche.xml within project directory
  puts "[LOG] Created new javalanche.xml file in project directory"
  file = File.open("#{@project_location}javalanche.xml", 'w')
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
  content << "-Djavalanche.maxmemory=#{@memory_for_tests}m "
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
    command << "-Djavalanche.maxmemory=#{@max_memory}m "
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
