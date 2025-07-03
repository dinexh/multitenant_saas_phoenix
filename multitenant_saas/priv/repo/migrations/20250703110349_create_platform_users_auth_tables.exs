defmodule MultitenantSaas.Repo.Migrations.CreatePlatformUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:platform_users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:platform_users, [:email])

    create table(:platform_users_tokens) do
      add :platform_user_id, references(:platform_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:platform_users_tokens, [:platform_user_id])
    create unique_index(:platform_users_tokens, [:context, :token])
  end
end
