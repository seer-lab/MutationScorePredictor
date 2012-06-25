@experiment_runs = 10
@experiment_resources_dir = "#{Dir.pwd}/lib/experiment_resources"

desc "Perform cross validation using all feature sets on the 'all' project"
task :cross_validation_all_features_experiment do

  features = Dir.entries("#{@experiment_resources_dir}/feature_sets").select {|entry| !File.directory? File.join("#{@experiment_resources_dir}/feature_sets",entry) and !(entry =='.' || entry == '..') }
  projects = Dir.entries("#{@experiment_resources_dir}/cross_validation").select {|entry| File.directory? File.join("#{@experiment_resources_dir}/cross_validation",entry) and !(entry =='.' || entry == '..') }

  features.each do |feature|

    FileUtils.cp("#{@experiment_resources_dir}/feature_sets/#{feature}", "#{@home}/lib/feature_sets.rb")

    projects.each do |project|

      # Ignore all other projects except the 'all' project
      next if project != "all"
      file = "#{@experiment_resources_dir}/cross_validation/#{project}/cross_validation_#{feature.chomp(".rb")}.txt"

      FileUtils.cp("#{@experiment_resources_dir}/cross_validation/#{project}/configuration.rb", "#{@home}/lib/rake_tasks/configuration.rb")
      if File.exist?(file)
        FileUtils.rm(file)
      end
      @experiment_runs.times do |i|
        `time rake cross_validation >> #{file}`
      end
    end
  end
end

desc "Perform cross validation using the three combined feature sets on all individual project"
task :cross_validation_all_projects_experiment do

  features = Dir.entries("#{@experiment_resources_dir}/feature_sets").select {|entry| !File.directory? File.join("#{@experiment_resources_dir}/feature_sets",entry) and !(entry =='.' || entry == '..') }
  projects = Dir.entries("#{@experiment_resources_dir}/cross_validation").select {|entry| File.directory? File.join("#{@experiment_resources_dir}/cross_validation",entry) and !(entry =='.' || entry == '..') }

  features.each do |feature|

    # Ignore all features that are not the combine sets
    next if !feature.include?("combine")

    FileUtils.cp("#{@experiment_resources_dir}/feature_sets/#{feature}", "#{@home}/lib/feature_sets.rb")

    projects.each do |project|

      # Ignore the 'all' project
      next if project == "all"
      file = "#{@experiment_resources_dir}/cross_validation/#{project}/cross_validation_#{feature.chomp(".rb")}.txt"

      FileUtils.cp("#{@experiment_resources_dir}/cross_validation/#{project}/configuration.rb", "#{@home}/lib/rake_tasks/configuration.rb")
      if File.exist?(file)
        FileUtils.rm(file)
      end
      @experiment_runs.times do |i|
        `time rake cross_validation >> #{file}`
      end
    end
  end
end

desc "Analyze the class/method mean and standard deviation of the experiment results"
task :analyze_experiment_results do

  features = Dir.entries("#{@experiment_resources_dir}/feature_sets").select {|entry| !File.directory? File.join("#{@experiment_resources_dir}/feature_sets",entry) and !(entry =='.' || entry == '..') }
  projects = Dir.entries("#{@experiment_resources_dir}/cross_validation").select {|entry| File.directory? File.join("#{@experiment_resources_dir}/cross_validation",entry) and !(entry =='.' || entry == '..') }

  projects.each do |project|
    features.each do |feature|
      file = "#{@experiment_resources_dir}/cross_validation/#{project}/cross_validation_#{feature.chomp(".rb")}.txt"
      if File.exist?(file)
        puts file
        print_mean_sd_accuracy("class", file)
        print_mean_sd_accuracy("method", file)
        puts ""
      end
    end
  end
end

def print_mean_sd_accuracy(type, file)
  total = []
  results = File.open(file, "r").read.scan(/#{type.capitalize} Accuracy = (\d*.\d*)/)
  results.each do |result|
    total << result[0].to_f
  end
  total = total.to_scale
  puts "#{type.capitalize} Mean = #{total.mean}"
  puts "#{type.capitalize} Standard Deviation = #{total.sd}"
end
