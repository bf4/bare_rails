require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
# require "active_record/railtie"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.setup(:default, Rails.env)


require 'rails/version'
require 'rails/application'
require 'rails-api/public_exceptions'

module Rails
  class Application < Rails::Engine
  end
end
module BareRails
  class Application < Rails::Application

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Disable the asset pipeline.
    config.assets.enabled = false

    def default_middleware_stack
      rails_four_stack
    end

    private

    def setup_generators!
      generators = config.generators

      generators.templates.unshift File::expand_path('../templates', __FILE__)
      generators.resource_route = :api_resource_route

      generators.hide_namespace "css"

      generators.rails({
        :helper => false,
        :assets => false,
        :stylesheets => false,
        :stylesheet_engine => nil,
        :template_engine => nil
      })
    end

    ActiveSupport.on_load(:before_configuration) do
      config.api_only = true
      setup_generators!
    end

    def rails_four_stack
      ActionDispatch::MiddlewareStack.new.tap do |middleware|
        app = self
        if rack_cache = config.action_dispatch.rack_cache
          begin
            require 'rack/cache'
          rescue LoadError => error
            error.message << ' Be sure to add rack-cache to your Gemfile'
            raise
          end

          if rack_cache == true
            rack_cache = {
              metastore: "rails:/",
              entitystore: "rails:/",
              verbose: false
            }
          end

          require "action_dispatch/http/rack_cache"
          middleware.use ::Rack::Cache, rack_cache
        end

        if config.force_ssl
          middleware.use ::ActionDispatch::SSL, config.ssl_options
        end

        if config.action_dispatch.x_sendfile_header.present?
          middleware.use ::Rack::Sendfile, config.action_dispatch.x_sendfile_header
        end

        if config.serve_static_assets
          middleware.use ::ActionDispatch::Static, paths["public"].first, config.static_cache_control
        end

        middleware.use ::Rack::Lock unless config.cache_classes
        middleware.use ::Rack::Runtime
        middleware.use ::ActionDispatch::RequestId
        middleware.use ::Rails::Rack::Logger, config.log_tags # must come after Rack::MethodOverride to properly log overridden methods
        middleware.use ::ActionDispatch::ShowExceptions, config.exceptions_app || ActionDispatch::PublicExceptions.new(Rails.public_path)
        middleware.use ::ActionDispatch::DebugExceptions, app
        middleware.use ::ActionDispatch::RemoteIp, config.action_dispatch.ip_spoofing_check, config.action_dispatch.trusted_proxies

        unless config.cache_classes
          middleware.use ::ActionDispatch::Reloader, lambda { app.reload_dependencies? }
        end

        middleware.use ::ActionDispatch::Callbacks

        middleware.use ::ActionDispatch::ParamsParser
        middleware.use ::Rack::Head
        middleware.use ::Rack::ConditionalGet
        middleware.use ::Rack::ETag, "no-cache"
      end
    end
  end
end
