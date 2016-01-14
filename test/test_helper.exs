defmodule TestRepo do
  use RethinkDB.Ecto.Repo, otp_app: :rethinkdb_ecto_test
  import Ecto.Changeset

  @required_fields ~w(title)
  @optional_fields ~w(content user date)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end

defmodule TestModel do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    field :content, :string
    field :user, :string
    field :date, Ecto.Date

    timestamps
  end
end

Application.put_env(:rethinkdb_ecto_test, TestRepo, [])

ExUnit.start()
