defmodule MultitenantSaas.Tenancy.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :alias, :string
    field :name, :string
    field :type, :string
    field :location, :string
    field :university, :string
    field :accreditation, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :alias, :location, :type, :university, :accreditation])
    |> validate_required([:name, :alias, :location, :type, :university, :accreditation])
    |> unique_constraint(:alias)
  end
end
