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
    ExtractMutants.new(@project_name,
      "#{@project_location}analyze.csv",
      "#{@project_location}mutation-files/tests_touched.csv").process

    CoverageMutationScorer.new(@project_name, @javalanche_operators).process
  else
    MutationScorer.new(@project_name,
      "#{@project_location}mutation-files/class-scores.csv",
      "#{@project_location}mutation-files/method-scores.csv").process
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
