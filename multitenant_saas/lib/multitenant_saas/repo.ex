defmodule MultitenantSaas.Repo do
  use Ecto.Repo,
    otp_app: :multitenant_saas,
    adapter: Ecto.Adapters.Postgres
end
