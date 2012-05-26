# DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/sqlite3.db")
# DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3::memory:")
DataMapper::Model.raise_on_save_failure = true

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/Desktop/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.1.0.v20100507.jar"
@eclipse_workspace = "/home/jalbert/workspace1/"
@project_run = 1
@project_builder = "ant"  # Project uses "ant" or "maven"
@project_name = "triangleJunit4"
@project_prefix = "triangle"
@project_tests = "triangle.tests.TriangleTestSuite"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@project_test_directory = "#{@project_location}src/triangle/tests/"  # Then prefix occurs
@project_src_directory = "#{@project_location}src/triangle/"  # Then prefix occurs
@max_memory = "4000"  # In megabytes (the max avalible memory)
@memory_for_tests = "4000"  # In megabytes (the memory needed for the test suite)
@max_cores = "4"
@javalanche_log_level = "ERROR"
@javalanche_coverage = true
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
@javalanche_properties = "-Djavalanche.project.source.dir=#{@project_src_directory} "\
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
