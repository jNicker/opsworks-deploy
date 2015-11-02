require 'opsworks/deploy/version'
require 'aws-sdk'
require 'yaml'

require 'pry'

module Opsworks::Deploy

  DEPLOYMENT_POLL_INTERVAL = 10

  require 'opsworks/deploy/railtie' if defined?(Rails)

  def self.deploy(options={})
    Deployment.new(options)
  end

  class Deployment

    def initialize(options)
      @options = {
        migrate: true,
        wait: true,
        env: nil
      }.merge(options)
      raise 'Must set stack_id for environment'   unless config.has_key?('stack_id')
      raise 'Must set app_id for environment'     unless config.has_key?('app_id')
      raise 'Must set region for environment'     unless config.has_key?('region')
      raise 'Must set iam_key for environment'    unless config.has_key?('iam_key')
      raise 'Must set iam_secret for environment' unless config.has_key?('iam_secret')
      deploy
    end

    def deploy
      Aws.config.update(access_key_id: config['iam_key'], secret_access_key: config['iam_secret'])
      @client = Aws::OpsWorks::Client.new(region: config['region'])
      @deployment = @client.create_deployment(deploy_args)
      wait_on_deployment if @options[:wait]
    end

    def config
      @config ||= configured_environments.fetch(current_environment)
    end

    private

    def deploy_args
      {
        stack_id: config['stack_id'],
        app_id: config['app_id'],
        command: {
          name: 'deploy',
          args: {
            'migrate' => [@options[:migrate] ? 'true' : 'false']
          }
        }
      }.tap { |args|
        args[:custom_json] = config['custom_json'].to_json if config.has_key?('custom_json')
      }
    end

    def current_environment
      @options.fetch(:env)
    end

    def configured_environments
      files = Dir['config/deploy/stacks.yml', 'config/stacks.yml','stacks.yml']
      file = files.first and YAML.load(File.read(file))
    end

    def custom_json
      config['custom_json'].to_json
    end

    def custom_json?
      config.has_key?('custom_json')
    end

    def wait_on_deployment
      deployment_id = @deployment.data[:deployment_id]
      loop do
        deployment_description = @client.describe_deployments(deployment_ids: [deployment_id])
        status = deployment_description.data[:deployments].first[:status]
        puts status
        case status
        when 'running' then sleep DEPLOYMENT_POLL_INTERVAL
        when 'successful' then break
        else
          raise "Failed to run deployment: #{deployment_id} - #{status}"
        end
      end
    end

  end

end

# require "opsworks/deploy/version"
# require 'aws-sdk'
# require 'yaml'
# require 'pry'

# module Opsworks::Deploy
#   DEPLOYMENT_POLL_INTERVAL = 10

#   require 'opsworks/deploy/railtie' if defined?(Rails)

#   def self.configure_aws!
#     # First, try to pull these from the environment
#     iam_key = ENV['IAM_KEY']
#     iam_secret = ENV['IAM_SECRET']

#     # Otherwise, we'll pull them from config
#     if ( iam_key.nil? || iam_secret.nil? ) && ENV['AWS_CONFIG_FILE']
#       config = File.read(ENV['AWS_CONFIG_FILE'])
#       iam_key = $1 if config =~ /^aws_access_key_id=(.*)$/
#       iam_secret = $1 if config =~ /^aws_secret_access_key=(.*)$/
#     end

#     raise ArgumentError, "Must set IAM_KEY environment variable" if iam_key.nil? || iam_key.length == 0
#     raise ArgumentError, "Must set IAM_SECRET environment variable" if iam_secret.nil? || iam_secret.length == 0
#     Aws.config.update(access_key_id: iam_key, secret_access_key: iam_secret)
#   end

#   def self.deploy(opts={})
#     Opsworks::Deploy.configure_aws!
#     Deployment.new(opts).deploy
#   end

#   class Deployment
#     attr_reader :client, :deployment, :options

#     def initialize(options, client = Aws::OpsWorks::Client.new(region: 'us-east-1'))
#       @options = {
#         migrate: true,
#         wait: true,
#         env: nil
#       }.merge(options)
#       @client = client
#     end

#     def deploy
#       @deployment = client.create_deployment(arguments)
#       puts @deployment.inspect
#       wait_on_deployment if options[:wait]
#     end

#     private

#     def arguments
#       {
#         stack_id: configuration['stack_id'],
#         app_id: configuration['app_id'],
#         command: command
#       }.tap do |args|
#         args[:custom_json] = custom_json if custom_json?
#       end
#     end

#     def command
#       {name: 'deploy', args: {'migrate' => [options[:migrate] ? 'true' : 'false']}}
#     end

#     def custom_json
#       configuration['custom_json'].to_json
#     end

#     def custom_json?
#       configuration.has_key?('custom_json')
#     end

#     def configuration
#       @configuration ||= if !ENV['STACK_ID'].nil? && !ENV['APP_ID'].nil?
#         {'stack_id' => ENV['STACK_ID'], 'app_id' => ENV['APP_ID']}
#       elsif stacks = configured_environments
#         stacks.fetch(environment) do
#           raise "Missing stacks configuration for #{environment} in stacks.json"
#         end
#       else
#         raise "Must set STACK_ID and APP_ID or have config/stacks.json for env `#{environment}`"
#       end
#     end

#     def environment
#       options.fetch(:env)
#     end

#     # Look for config/deploy/stacks.yml or config/stacks.yml or stacks.yml
#     def configured_environments
#       files = Dir['config/deploy/stacks.yml', 'config/stacks.yml','stacks.yml']
#       file = files.first and YAML.load(File.read(file))
#     end

#     def wait_on_deployment
#       deployment_id = deployment.data[:deployment_id]
#       loop do
#         deployment_description = client.describe_deployments(deployment_ids: [deployment_id])
#         status = deployment_description.data[:deployments].first[:status]
#         puts status
#         case status
#         when 'running' then sleep DEPLOYMENT_POLL_INTERVAL
#         when 'successful' then break
#         else
#           raise "Failed to run deployment: #{deployment_id} - #{status}"
#         end
#       end
#     end
#   end

# end
