import Config

if System.get_env("PHX_SERVER") do
  config :melocoton, MelocotonWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/melocoton/melocoton.db
      """

  config :melocoton, Melocoton.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :melocoton, MelocotonWeb.Endpoint,
    url: [host: host],
    http: [ip: {127, 0, 0, 1}, port: port],
    secret_key_base: secret_key_base
end
