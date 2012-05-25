begin
  require "rake/clean"
  require "open-uri"
  require "archive"
  require "nokogiri"
  require "data_mapper"
  require "awesome_print"
  require "statsample"
  require "./mutation_scorer.rb"
  require "./coverage_mutation_scorer.rb"
  require "./extract_mutants.rb"
  require "./extract_source_metrics.rb"
  require "./metric_libsvm_synthesizer.rb"
  require "./test_suite_method_metrics.rb"
  require "./class_metric_accumulator.rb"
  require "./method_data.rb"
  require "./class_data.rb"
  require "./mutant_data.rb"
rescue LoadError
  abort "Gems missing. Try use `bundle install`."
end


# DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/sqlite3.db")
# DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3::memory:")
DataMapper::Model.raise_on_save_failure = true

# This rakefile is used to set up the working environment for the mutation
# score predictor project. There are tasks to download and set up the required
# mutation testing tool Javalanche. Other tasks are present to aid the user in
# running the experiment.
#
# @author Kevin Jalbert
# @version 0.8.0

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/Desktop/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.1.0.v20100507.jar"
@eclipse_workspace = "/home/jalbert/workspace1/"
@project_run = 1
@project_name = "jgap_3.6.1_full"
@project_prefix = "org.jgap"
@project_tests = "org.jgap.AllTests"
@project_builder = "ant"  # Project uses "ant" or "maven"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@project_test_directory = "#{@project_location}tests/"  # Then prefix occurs
@project_src_directory = "#{@project_location}src/"  # Then prefix occurs
@max_memory = "4000"  # In megabytes (the max avalible memory)
@memory_for_tests = "2000"  # In megabytes (the memory needed for the test suite)
@max_cores = "4"
@javalanche_log_level = "ERROR"
@javalanche_coverage = false
@python = "python2"  # Python 2.7 command
@rake = "rake"  # Rake command
@classpath = ""  # Acquired through ant/maven extraction

# Variables related to Javalanche's database usage
@use_mysql = false
@mysql_database = "mutation_test"
@mysql_user = "root"
@mysql_password = "root"

# Enable/Disable/Filter Javalanche mutation operators
@javalanche_operators = {
                          "NO_MUTATION" => true,
                          "REPLACE_CONSTANT" => true,
                          "NEGATE_JUMP" => true,
                          "ARITHMETIC_REPLACE" => true,
                          "REMOVE_CALL" => true,
                          "REPLACE_VARIABLE" => true,
                          "ABSOLUTE_VALUE" => true,
                          "UNARY_OPERATOR" => true,
                          "REPLACE_THREAD_CALL" => false,
                          "MONITOR_REMOVE" => false,
                        }

# Variables related to setup and execution
@home = Dir.pwd
@eclipse_project_build = "#{@project_location}build.xml"
@eclipse_metric_plugin = "#{@eclipse}plugins/" \
                         "net.sourceforge.metrics_1.3.8.20100730-001.jar"
@eclipse_metrics_xml_reader_git = "git://github.com/kevinjalbert/" \
                                  "eclipse_metrics_xml_reader.git"
@javalanche = "javalanche-0.4"
@javalanche_download = "git://github.com/kevinjalbert/javalanche.git"
@javalanche_branch = nil
@javalanche_location = "#{@home}/#{@javalanche}"
@javalanche_project_file = "#{@project_location}javalanche.xml"
@javalanche_properties = "-Djavalanche.stop.after.first.fail=false " \
  "-Djavalanche.project.source.dir=#{@project_src_directory} "\
  "-Djavalanche.enable.arithmetic.replace=#{@javalanche_operators["ARITHMETIC_REPLACE"]} " \
  "-Djavalanche.enable.negate.jump=#{@javalanche_operators["NEGATE_JUMP"]} " \
  "-Djavalanche.enable.remove.call=#{@javalanche_operators["REMOVE_CALL"]} " \
  "-Djavalanche.enable.replace.constant=#{@javalanche_operators["REPLACE_CONSTANT"]} " \
  "-Djavalanche.enable.replace.variable=#{@javalanche_operators["REPLACE_VARIABLE"]} " \
  "-Djavalanche.enable.absolute.value=#{@javalanche_operators["ABSOLUTE_VALUE"]} " \
  "-Djavalanche.enable.unary.operator=#{@javalanche_operators["UNARY_OPERATOR"]} " \
  "-Djavalanche.enable.monitor.remove=#{@javalanche_operators["MONITOR_REMOVE"]} " \
  "-Djavalanche.enable.replace.thread.call=#{@javalanche_operators["REPLACE_THREAD_CALL"]} "
@libsvm = "libsvm-3.12"
@libsvm_tar = "#{@libsvm}.tar.gz"
@libsvm_download = "http://www.csie.ntu.edu.tw/~cjlin/libsvm/#{@libsvm_tar}"
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
CLOBBER.include("./SingleJUnitTestRunner.jar")
CLOBBER.include("./sqlite3.db")
CLEAN.include("./data")

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

desc "Install the necessary components for this project"
task :install => [:sqlite3, :install_javalanche,
                  :install_eclipse_metrics_xml_reader, :install_libsvm,
                  :install_emma, :install_junit] do

  puts "[LOG] Performing an auto_migrate on sqlite3.db"
  DataMapper.auto_migrate!

  puts "[LOG] Necessary components are present and ready"
end

# Ready sqlite3 DB
task :sqlite3 do
  puts "[LOG] Ready sqlite3 DB"
  DataMapper.finalize
end

# Install Javalanche
task :install_javalanche do

  # Perform install only if Javalanche directory doesn't exist
  if not File.directory?(@javalanche)


    puts "[LOG] Cloning Javalanche"
    sh "git clone #{@javalanche_download}"

    # Compile Javalanche and place in proper place
    Dir.chdir("javalanche") do

      if @javalanche_branch != nil
        sh "git checkout origin/#{@javalanche_branch}"
      end

      puts "[LOG] Compiling Javalanche"
      sh "sh makeDist.sh"

      puts "[LOG] Moving #{@javalanche}"
      cp_r @javalanche, "./../#{@javalanche}"
    end

    puts "[LOG] Removing Javalanche's source"
    rm_r "javalanche"

    # Configure the usage of Javalanche's database
    if @use_mysql
      puts "[LOG] Adjusting hibernate.cfg to use MySQL instead of HSQLDB"

      file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'r')
      content = file.read
      file.close

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

      file = File.open("#{@javalanche}/src/main/resources/hibernate.cfg.xml", 'w')
      file.write(content)
      file.close
    end

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

  # Perform install only if Eclipse metrics directory doesn't exist
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

    # Patching svm-train.c
    puts "[LOG] Patching svm-train.c"
    sh "patch ./#{@libsvm}/svm-train.c -i svm-train.c.patch"

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

  puts "[LOG] Creating Custom JUnit Test Runner (SingleJUnitTestRunner)"
  sh "javac -cp junit-4.8.1.jar SingleJUnitTestRunner.java"
  sh "jar cf SingleJUnitTestRunner.jar SingleJUnitTestRunner.class"
  rm "SingleJUnitTestRunner.class"
end

# Set up support vector machine using the mutation scores and metrics
desc "Set up the support vector machine for training"
task :setup_svm => [:sqlite3, :get_mutation_scores, :extract_metrics,
                    :install_emma] do

  run_emma

  # Add test metrics to the methods's metrics
  puts "[LOG] Adding testing metrics to method metrics"
  TestSuiteMethodMetrics.new(@project_name, @project_run).process

  # Accumulating metrics from methods into the classes
  puts "[LOG] Accumulating metrics from methods into classes"
  ClassMetricAccumulator.new(@project_name, @project_run).process

  # Recap on the memory and cores used
  puts "Resource Summary:"
  puts "  Used #{number_of_tasks} tasks for mutation testing"
  puts "  Used #{@memory_for_tests}m memory for mutation testing tasks"
  puts "  Used #{@max_memory}m memory for Emma coverage"
end

# Update support vector machine using the enabled mutation operators given that
# the setup_svm task was ran using coverage.
desc "Update up the support vector machine for training (using coverage data)"
task :update_svm => [:sqlite3, :install_emma] do

  # Check if there is data to update from
  if MutantData.count(:project => @project_name, :run => @project_run) > 0

    # Extract mutation scores from Javalanche
    puts "[LOG] Updating mutation scores from Javalanche results"
    CoverageMutationScorer.new(@project_name, @project_run, @javalanche_operators).process

    # Re-acquire the coverage metrics
    find_and_set_classpath
    run_emma

    # Handle the source metrics
    if MethodData.count(:project => @project_name, :run => @project_run, :mloc.gt => 0) > 0
      puts "[LOG] Updating the occurs of class/method to 2 (source metrics already exist)"
      MethodData.all(:project => @project_name, :run => @project_run).update(:occurs => 2)
      ClassData.all(:project => @project_name, :run => @project_run).update(:occurs => 2)
    else
      extract_metrics
    end

    # Add test metrics to the methods's metrics
    puts "[LOG] Adding testing metrics to method metrics"
    TestSuiteMethodMetrics.new(@project_name, @project_run).process

    # Accumulating metrics from methods into the classes
    puts "[LOG] Accumulating metrics from methods into classes"
    ClassMetricAccumulator.new(@project_name, @project_run).process

    # Recap on the memory and cores used
    puts "Resource Summary:"
    puts "  Used #{number_of_tasks} tasks for mutation testing"
    puts "  Used #{@memory_for_tests}m memory for mutation testing tasks"
    puts "  Used #{@max_memory}m memory for Emma coverage"
  else
    puts "[ERROR] No mutant data to update the SVM with (run setup_svm with coverage)"
  end
end

# Calculate statistics on the project
desc "Calculate statistics on the project (correlation, distribution, etc...)"
task :statistics => [:sqlite3] do

  # Check if there is data to update from
  if MethodData.count(:project => @project_name, :run => @project_run) > 0
    puts "[LOG] Calculating statistics of data set"
    MetricLibsvmSynthesizer.new(@project_name, @project_run, @home).statistics
  else
    puts "[ERROR] No data to cacluate statistics on (run setup_svm)"
  end
end

# Perform cross validation of the project
desc "Perform cross validation on the project"
task :cross_validation => [:sqlite3] do

  puts "[LOG] Creating .libsvm files"
  MetricLibsvmSynthesizer.new(@project_name, @project_run, @home).process

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
      class_output = `#{@python} easy.py ./../../data/#{@project_name}_class_#{@project_run}.libsvm`
      class_values = class_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]
      method_output = `#{@python} easy.py ./../../data/#{@project_name}_method_#{@project_run}.libsvm`
      method_values = method_output.scan(/Best c=(\d+\.?\d*), g=(\d+\.?\d*) CV rate=(\d+\.?\d*)/)[0]

      puts "[LOG] Acquiring detailed results of cross validation"
      `../svm-train -v #{@cross_validation_folds} -c #{class_values[0]} -g #{class_values[1]} ./#{@project_name}_class_#{@project_run}.libsvm.scale`
      cp("./prediction_file.csv", "../../data/#{@project_name}_class_#{@project_run}_prediction.csv")
      `../svm-train -v #{@cross_validation_folds} -c #{method_values[0]} -g #{method_values[1]} ./#{@project_name}_method_#{@project_run}.libsvm.scale`
      cp("./prediction_file.csv", "../../data/#{@project_name}_method_#{@project_run}_prediction.csv")

      puts "[LOG] Class Accuracy = #{class_values[2]}%"
      puts "[LOG] Best Class Configuration = -c #{class_values[0]} -g #{class_values[1]}"

      puts "[LOG] Method Accuracy = #{method_values[2]}%"
      puts "[LOG] Best Method Configuration = -c #{method_values[0]} -g #{method_values[1]}"

    end
  end
end

# Extract metric XML file into sqlite DB
task :extract_metrics => [:sqlite3, :get_eclipse_metrics_xml,
                          :install_eclipse_metrics_xml_reader] do

    puts "[LOG] Converting metrics to csv format"
    sh "#{@python} " \
       "./eclipse_metrics_xml_reader/src/eclipse_metrics_xml_reader.py -i " \
       "./data/#{@project_name}.xml -t csv"

    puts "[LOG] Extract metric from csv format into sqlite3 DB"
    ExtractSourceMetrics.new(@project_name, @project_run,
    "#{@home}/data/#{@project_name}_class.csv",
    "#{@home}/data/#{@project_name}_method.csv").process
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
task :get_mutation_scores => [:sqlite3, :install_javalanche,
                              :setup_javalanche] do

  # Run javalanche
  Dir.chdir(@project_location) do
    puts "[LOG] Executing Javalanche command"
    sh "#{create_javalanche_command("getMutationScores")}"
  end

  # Extract mutation scores from Javalanche
  puts "[LOG] Extracting mutation scores from Javalanche results"
  if @javalanche_coverage
    ExtractMutants.new(@project_name, @project_run,
      "#{@project_location}analyze.csv",
      "#{@project_location}mutation-files/tests_touched.csv").process

    CoverageMutationScorer.new(@project_name, @project_run, @javalanche_operators).process
  else
    MutationScorer.new(@project_name, @project_run,
      "#{@project_location}mutation-files/class-scores.csv",
      "#{@project_location}mutation-files/method-scores.csv").process
  end
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
  content << "startHsql,schemaexport,scanProject,scan,createTasks,createMutationMakefile"
  if @javalanche_coverage
    content << ",createCoverageDataMult,checkCoverageData\">"
  else
    content << "\">"
  end
  content << "\n        <exec executable=\"make\" spawn=\"false\">"
  content << "\n            <arg value=\"-j#{number_of_tasks}\"/>"
  content << "\n        </exec>"
  content << "\n        <property name=\"javalanche.mutation.analyzers\" value"
  content << "=\"de.unisb.cs.st.javalanche.mutation.analyze.MutationScoreAnalyzer,"
  content << "de.unisb.cs.st.javalanche.mutation.analyze.TestsTouchedAnalyzer"
  if @javalanche_coverage
    content << ",de.unisb.cs.st.javalanche.coverage.CoverageAnalyzer\" />"
  else
    content << "\" />"
  end
  content << "\n        <antcall target=\"analyzeResults\" />"
  content << "\n        <antcall target=\"stopHsql\" />"
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
  if @javalanche_coverage
    content << "\n        #{create_javalanche_command("runMutationsCoverage")} "
  else
    content << "\n        #{create_javalanche_command("runMutations")} "
  end
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
    command = "nice -10 ant -f javalanche.xml -Dprefix=#{@project_prefix} "
    command << "-Dcp=#{@classpath} -Dtests=#{@project_tests} "
    command << "-Djavalanche.maxmemory=#{@max_memory}m "
    command << "-Djavalanche.log.level=#{@javalanche_log_level} "
    command << "-Djavalanche=#{@javalanche_location} "
    command << "-Djavalanche.properties=\"#{@javalanche_properties}\" #{task}"
  return command
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

def run_emma

  completed_tests = Hash.new
  count = 1

  # Use all the methods that have a mutation score and source metrics
  MethodData.all(:project => @project_name, :run => @project_run, :usable => true, :tests_touched.not => "").each do |method|

    Dir.chdir(@project_location) do

      testing = ""
      # Build string of testing concrete tests, while ignoring abstract tests
      method.tests_touched.split(" ").each do |test|

        # Acquire the actual file path of the test
        file = "#{@project_test_directory}#{test.rpartition(".").first.gsub(".",File::Separator)}.java"

        # Seems that tests with the '$' still works via a system call (it will
        #   actually ignore everything after the '$' till the '.')
        # Check to see if the file is an abstract class, we'll ignore these
        if system("egrep abstract\\\s+class #{file}")
          puts "[INFO] Ignoring abstract test case #{test}"
          next
        end
        testing += test.rpartition(".").first + "#" + test.rpartition(".").last + " "
      end

      # Only execute the coverage test if it hasn't already been executed
      if completed_tests.has_key?(testing)
        puts "[LOG] Test coverage already executed, copying old results"
        cp("#{@home}/data/#{completed_tests[testing]}", "#{@home}/data/coverage#{count}.xml")
      else
        emma = "-cp #{@home}/#{@emma}/lib/emma.jar emmarun -r xml"
        opts = "-Dreport.sort=-method -Dverbosity.level=silent " \
              "-Dreport.columns=name,line,block -Dreport.depth=method " \
              "-Dreport.xml.out.file=coverage#{count}.xml " \
              "-ix +#{@project_prefix}.* "
        command = "java -Xmx#{@max_memory}m #{emma} -cp " \
              "#{@home}/#{@junit_jar}:#{@home}/SingleJUnitTestRunner.jar:" \
              "#{@classpath} #{opts}"

        # Store tests in txt file to avoid 'arguments too long' error
        file = File.open("tests#{count}.txt", 'w')
        file.write(testing)
        file.close

        # Store the output of the JUnit tests
        output = `#{command} SingleJUnitTestRunner $(cat tests#{count}.txt)`
        rm("tests#{count}.txt")

        # Handle output, it might have errors, nothing or results
        if output.include?("fail")
          puts "[ERROR] With Emma JUnit testing"
          file = File.open("#{@home}/data/coverage#{count}.xml", 'w')
          file.write("")
          file.close
        else
          mv("coverage#{count}.xml", "#{@home}/data/")
        end

        # Store this test coverage to reduce number of executions
        completed_tests[testing] = "coverage#{count}.xml"
      end
      count += 1
    end
  end
end

# Test if the project can run through javalanche with no problems
task :test_project => [:install_javalanche, :setup_javalanche] do

  # Run javalanche's test tasks to ensure project is capable to run
  Dir.chdir(@project_location) do

    rm "./mutation-files/failed-tests.xml" if File.exists?("./mutation-files/failed-tests.xml")
    rm "./mutation-files/failing-tests-permuted.txt" if File.exists?("./mutation-files/failing-tests-permuted.txt")

    puts "[LOG] Test Javalanche command (testTask2)"
    sh "#{create_javalanche_command("testTask2")}"
    sh "cat ./mutation-files/failed-tests.xml" if File.exists?("./mutation-files/failed-tests.xml")

    puts "[LOG] Test Javalanche command (testTask3)"
    sh "#{create_javalanche_command("testTask3")}"
    sh "cat ./mutation-files/failing-tests-permuted.txt" if File.exists?("./mutation-files/failing-tests-permuted.txt")
  end
end
