defmodule ConfigTest do
  use ExUnit.Case

  import Mock

  test_with_mock "it should use config", RethinkDB.Connection, [:passthrough], [] do
    Application.put_env(:rethinkdb_ecto_test, TestRepo, [
      hostname: "127.0.0.8",
      port: 1,
      database: "t",
      auth_key: "hi"
    ])
    TestRepo.start_link
    assert called RethinkDB.Connection.start_link([
      name: TestRepo,
      host: "127.0.0.8",
      port: 1,
      db: "t",
      auth_key: "hi"
    ])
    TestRepo.stop
  end
end
