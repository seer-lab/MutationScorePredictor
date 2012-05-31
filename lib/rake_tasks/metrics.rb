# Creates the build file needed to execute the headless Eclipse metrics plugin
task :setup_metrics_build_file do

  # If no build file exists just make one
  if !File.exist?(@eclipse_project_build + ".backup")
    puts "[WARN] No build.xml file was found, creating an empty one"
    FileUtils.touch(@eclipse_project_build)
  end

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

# Extract metric XML file into sqlite DB
task :extract_metrics => [:sqlite3, :get_eclipse_metrics_xml,
                          :install_eclipse_metrics_xml_reader] do

    puts "[LOG] Converting metrics to csv format"
    sh "#{@python} " \
       "./eclipse_metrics_xml_reader/src/eclipse_metrics_xml_reader.py -i " \
       "./data/#{@project_name}.xml -t csv"

    puts "[LOG] Extract metric from csv format into sqlite3 DB"
    ExtractSourceMetrics.new(@project_name,
    "#{@home}/data/#{@project_name}_class.csv",
    "#{@home}/data/#{@project_name}_method.csv").process
end
