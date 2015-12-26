defmodule TestRepo do
  use RethinkDB.Ecto.Repo, otp_app: :rethinkdb_ecto_test
end

Application.put_env(:rethinkdb_ecto_test, TestRepo, [])

ExUnit.start()
