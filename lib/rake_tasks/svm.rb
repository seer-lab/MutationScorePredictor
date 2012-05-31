# Set up support vector machine using the mutation scores and metrics
desc "Set up the support vector machine for training"
task :setup_svm => [:sqlite3, :get_mutation_scores, :extract_metrics,
                    :install_emma] do

  run_emma

  # Add test metrics to the methods's metrics
  puts "[LOG] Adding testing metrics to method metrics"
  TestSuiteMethodMetrics.new(@project_name).process

  # Accumulating metrics from methods into the classes
  puts "[LOG] Accumulating metrics from methods into classes"
  ClassMetricAccumulator.new(@project_name).process

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
  if MutantData.count(:project => @project_name) > 0

    # Extract mutation scores from Javalanche
    puts "[LOG] Updating mutation scores from Javalanche results"
    CoverageMutationScorer.new(@project_name, @javalanche_operators).process

    # Re-acquire the coverage metrics
    find_and_set_classpath
    run_emma

    # Handle the source metrics
    if MethodData.count(:project => @project_name, :mloc.gt => 0) > 0
      puts "[LOG] Updating the occurs of class/method to 2 (source metrics already exist)"
      MethodData.all(:project => @project_name).update(:occurs => 2)
      ClassData.all(:project => @project_name).update(:occurs => 2)
    else
      extract_metrics
    end

    # Add test metrics to the methods's metrics
    puts "[LOG] Adding testing metrics to method metrics"
    TestSuiteMethodMetrics.new(@project_name).process

    # Accumulating metrics from methods into the classes
    puts "[LOG] Accumulating metrics from methods into classes"
    ClassMetricAccumulator.new(@project_name).process

    # Recap on the memory and cores used
    puts "Resource Summary:"
    puts "  Used #{number_of_tasks} tasks for mutation testing"
    puts "  Used #{@memory_for_tests}m memory for mutation testing tasks"
    puts "  Used #{@max_memory}m memory for Emma coverage"
  else
    puts "[ERROR] No mutant data to update the SVM with (run setup_svm with coverage)"
  end
end

# TODO Refactor this (remove cloned code)
def run_emma

  completed_tests = Hash.new
  count = 1

  # Use all the methods that have a mutation score and source metrics
  MethodData.all(:project => @project_name, :usable => true, :tests_touched.not => "").each do |method|

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
        cp("#{@home}/data/#{completed_tests[testing]}", "#{@home}/data/coverage_m_#{count}.xml")
      else
        emma = "-cp #{@home}/#{@emma}/lib/emma.jar emmarun -r xml"
        opts = "-Dreport.sort=-method -Dverbosity.level=silent " \
              "-Dreport.columns=name,line,block -Dreport.depth=method " \
              "-Dreport.xml.out.file=coverage_m_#{count}.xml " \
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
          file = File.open("#{@home}/data/coverage_m_#{count}.xml", 'w')
          file.write("")
          file.close
        else
          mv("coverage_m_#{count}.xml", "#{@home}/data/")
        end

        # Store this test coverage to reduce number of executions
        completed_tests[testing] = "coverage_m_#{count}.xml"
      end
      count += 1
    end
  end

  completed_tests = Hash.new
  count = 1

  # Use all the class that have a mutation score and source metrics
  ClassData.all(:project => @project_name, :usable => true, :tests_touched.not => "").each do |class_item|

    Dir.chdir(@project_location) do

      testing = ""
      # Build string of testing concrete tests, while ignoring abstract tests
      class_item.tests_touched.split(" ").each do |test|

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
        cp("#{@home}/data/#{completed_tests[testing]}", "#{@home}/data/coverage_c_#{count}.xml")
      else
        emma = "-cp #{@home}/#{@emma}/lib/emma.jar emmarun -r xml"
        opts = "-Dreport.sort=-method -Dverbosity.level=silent " \
              "-Dreport.columns=name,line,block -Dreport.depth=method " \
              "-Dreport.xml.out.file=coverage_c_#{count}.xml " \
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
          file = File.open("#{@home}/data/coverage_c_#{count}.xml", 'w')
          file.write("")
          file.close
        else
          mv("coverage_c_#{count}.xml", "#{@home}/data/")
        end

        # Store this test coverage to reduce number of executions
        completed_tests[testing] = "coverage_c_#{count}.xml"
      end
      count += 1
    end
  end
end
