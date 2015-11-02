
namespace :opsworks do

  desc 'Deploy to Opsworks'
  task :deploy, [:env] => [] do |t, args|
    env = args[:env] || ENV['RAILS_ENV']
    migrate = true
    raise ArgumentError, "Please pass env as argument or set ENV or RAILS_ENV environment var" if env.nil? || env == ""
    puts "Attempting Deploy of #{env}#{migrate ? " and running migrations" : ""}..."
    Opsworks::Deploy.deploy(env: env, migrate: migrate)
    puts "Finished successfully"
  end

end
