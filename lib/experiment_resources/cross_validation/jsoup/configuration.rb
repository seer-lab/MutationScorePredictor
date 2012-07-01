# DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/sqlite3.db")
# DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3::memory:")
DataMapper::Model.raise_on_save_failure = true

# Project and environment variables (absolute paths) (user must/can modify)
@eclipse = "/home/jalbert/eclipse/"
@eclipse_launcher = "#{@eclipse}plugins/" \
           "org.eclipse.equinox.launcher_1.2.0.v20110502.jar"
@eclipse_workspace = "/home/jalbert/workspace4/"
@project_builder = "ant"  # Project uses "ant" or "maven"
@project_name = "triangleJunit4"
@project_prefix = "triangle"
@project_tests = "triangle.tests.TriangleTestSuite"
@project_location = "#{@eclipse_workspace}#{@project_name}/"
@project_test_directory = "#{@project_location}src/triangle/tests/"  # Then prefix occurs
@project_src_directory = "#{@project_location}src/triangle/"  # Then prefix occurs
@max_memory = "4000"  # In megabytes (the max avalible memory)
@memory_for_tests = "4000"  # In megabytes (the memory needed for the test suite)
@max_cores = "8"
@javalanche_log_level = "INFO"
@javalanche_coverage = true
@python = "python"  # Python 2.7 command
@rake = "rake"  # Rake command
@classpath = ""  # Acquired through ant/maven extraction

# Variables related to Evaluation (cross-validation, prediction, statistics)
#   projects_one is the primary set of projects to use, while projects_two is
#   to be used for prediction accross projects (train on one, predict on two)
@projects = [  # Do not comment these out, they are the general set
              "barbecue-1.5-beta1",
              "commons-lang-3.3.1",
              "jgap_3.6.1_full",
              "joda-primitives-1.0",
              "joda-time-2.0",
              "jsoup-1.6.2",
              "logback-core",
              "openfast-1.1.0"
            ]
@evaluation_projects_one = [
                            #"barbecue-1.5-beta1",
                            #"commons-lang-3.3.1",
                            #"jgap_3.6.1_full",
                            # "joda-primitives-1.0",
                            #"joda-time-2.0",
                            "jsoup-1.6.2",
                            #"logback-core",
                            #"openfast-1.1.0",
                            ""
                          ]
@evaluation_projects_two = [
                            #"barbecue-1.5-beta1",
                            #"commons-lang-3.3.1",
                            #"jgap_3.6.1_full",
                            # "joda-primitives-1.0",
                            #"joda-time-2.0",
                            "jsoup-1.6.2",
                            #"logback-core",
                            #"openfast-1.1.0",
                            ""
                          ]
@@evaluation_seed = Random.new(srand)  # Use srand or actual seed value
@@bounds = [[0.00, 0.70], [0.70, 0.90], [0.90, 1.00]]  # Category bound values
@@divisor = 1  # Amount to divide the undersampled data by (use less of it)
@divisor_range = (1..10).to_a  # The increments used for experiments
@only_unknowns = true  # Use only the unknown (untrained) items if possible

# Statistics variables
@@percentiles = [25,50,75]  # Must be in ascending order

# Grid Search variables
@lower_bound = 0.001
@cost_limit = 1000
@gamma_limit = 1000
@step_multiplier = 10
@run = 10
@sort_symbol = "f_score"  # accuracy || f_score || coarse_auroc || youden_index

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
