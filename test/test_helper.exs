defmodule TestRepo do
  use RethinkDB.Ecto.Repo, otp_app: :rethinkdb_ecto_test
end

defmodule TestModel do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    field :content, :string
    field :user, :string
   
    timestamps
  end
end

Application.put_env(:rethinkdb_ecto_test, TestRepo, [])

ExUnit.start()
