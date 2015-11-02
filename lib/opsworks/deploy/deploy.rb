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

