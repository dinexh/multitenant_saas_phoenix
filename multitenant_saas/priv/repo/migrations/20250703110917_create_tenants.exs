defmodule MultitenantSaas.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants) do
      add :name, :string
      add :alias, :string
      add :location, :string
      add :type, :string
      add :university, :string
      add :accreditation, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:alias])
  end
end
