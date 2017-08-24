require 'support/bootstrap/db_config'
require 'support/paths'

I18n.enforce_available_locales = false # avoid deprecation warning

module TestConfig
  def self.override(overrides)
    @config = load(overrides)
  end

  def self.reset
    TestConfig.override({})
  end

  def self.config
    @config ||= load
  end

  def self.load(overrides={})
    config = defaults.merge(overrides)
    configure_components(config)
    config
  end

  def self.configure_components(config)
    # Always enable Fog mocking (except when using a local provider, which Fog can't mock).
    res_pool_connection_provider = config[:resource_pool][:fog_connection][:provider].downcase
    packages_connection_provider = config[:packages][:fog_connection][:provider].downcase
    Fog.mock! unless res_pool_connection_provider == 'local' || packages_connection_provider == 'local'

    # reset dependency locator
    dependency_locator = CloudController::DependencyLocator.instance
    dependency_locator.reset(config)
    VCAP::CloudController::Config.configure_components(config)
    VCAP::CloudController::Config.configure_runner_components

    # configure the dependency locator
    CloudController::DependencyLocator.instance.config = config

    stacks_file = File.join(Paths::FIXTURES, 'config/stacks.yml')
    VCAP::CloudController::Stack.configure(stacks_file)
  end

  def self.defaults
    config_file = File.join(Paths::CONFIG, 'cloud_controller.yml')
    config_hash = VCAP::CloudController::Config.from_file(config_file)

    config_hash.update(
      nginx: { use_nginx: true },
      resource_pool: {
          resource_directory_key: 'spec-cc-resources',
          fog_connection: {
              blobstore_timeout: 5,
              provider: 'AWS',
              aws_access_key_id: 'fake_aws_key_id',
              aws_secret_access_key: 'fake_secret_access_key',
          },
      },
      packages: {
          app_package_directory_key: 'cc-packages',
          fog_connection: {
              blobstore_timeout: 5,
              provider: 'AWS',
              aws_access_key_id: 'fake_aws_key_id',
              aws_secret_access_key: 'fake_secret_access_key',
          },
      },
      droplets: {
          droplet_directory_key: 'cc-droplets',
          fog_connection: {
              blobstore_timeout: 5,
              provider: 'AWS',
              aws_access_key_id: 'fake_aws_key_id',
              aws_secret_access_key: 'fake_secret_access_key',
          },
      },

      db: DbConfig.new.config
    )

    config_hash
  end
end
