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
