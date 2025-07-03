defmodule MultitenantSaas.Tenancy do
  import Ecto.Query, warn: false
  alias MultitenantSaas.Repo
  alias MultitenantSaas.Tenancy.Tenant
  alias Triplex

  def create_tenant(attrs) do
    Triplex.create(Map.get(attrs, "alias") || Map.get(attrs, :alias))

    case Repo.transaction(fn ->
           %Tenant{}
           |> Tenant.changeset(attrs)
           |> Repo.insert()
           |> case do
             {:ok, tenant} ->
               Triplex.create(tenant.alias)
               {:ok, tenant}

             error ->
               error
           end
         end) do
      {:ok, result} -> result
      error -> error
    end
  end
end
