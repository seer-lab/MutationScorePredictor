begin
  require 'rake/clean'
  require 'open-uri' 
  require 'archive'
rescue LoadError
  abort "Required gems are not installed. Try 'sudo rake gems'."
end

# This rakefile is used to set up the working environment for the mutation 
# score predictor project. There are tasks to download and set up the required
# mutation testing tool Javalanche. Other tasks are present to aid the user in
# running the experiment.
#
# @author Kevin Jalbert
# @version 0.1.0

@javalanche = "javalanche-0.3.6"
@javalanche_tar = "#{@javalanche}-bin.tar.gz"
@javalanche_download = "http://www.st.cs.uni-saarland.de/~schuler/" \
                       "javalanche/builds/#{@javalanche_tar}"

# Files to remove via clobbering them
CLOBBER.include("./#{@javalanche}")

task :default => :list

# Displays the available commands as well as required tools
task :list do
  sh "rake -T"
  puts "\nWork flow: 'install' -> make changes -> 'make_patch' -> commit"
  puts "\n'ant' and 'mvn' are required to build and use Javalanche"
end

# Installs the necessary ruby gems to perform all the tasks
desc "Installs required gems"
task :gems do
  sh "gem install libarchive-ruby"
end

# Installs Javalanche
task :install do

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

  else
    puts "\nDirectory #{@javalanche} already exists"
  end
end
