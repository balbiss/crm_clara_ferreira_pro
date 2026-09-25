require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CrmBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Sem isso, Rails.zone (e todo .strftime feito em cima de created_at/
    # Time.current) caía no default UTC -- horário certo só aparecia onde o
    # frontend formatava a partir de um timestamp cru (ex: mensagem dentro
    # da conversa, que manda ISO8601 e o navegador formata local). Lugares
    # que já formatam "HH:MM" pronto no backend (ex: preview da lista de
    # conversas, conversations_controller.rb) mostravam 3h a mais que o
    # horário real (dono reportou, 2026-09-25). Continua gravando em UTC no
    # banco (padrão do Postgres/Rails) -- só a INTERPRETAÇÃO/exibição via
    # Time.zone muda.
    config.time_zone = "America/Sao_Paulo"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.i18n.default_locale = :'pt-BR'
    config.i18n.available_locales = [:'pt-BR', :en]
  end
end
