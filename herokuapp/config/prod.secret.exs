use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :twitterphx, TwitterphxWeb.Endpoint,
  secret_key_base: "LVXAyTb5ZRt/nU7zbLXDJzCvd68ld846iKaMsBT9j/Ie62nAsAoztm08d2hlZlgD"

# Configure your database
config :twitterphx, Twitterphx.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "twitterphx_prod",
  pool_size: 15
