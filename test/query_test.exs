defmodule QueryTest do
  use ExUnit.Case

  setup_all do
    Application.put_env(:rethinkdb_ecto_test, TestRepo, [])

    {:ok, conn} = RethinkDB.Connection.start_link
    {:ok, _} = TestRepo.start_link
    RethinkDB.Query.table_create("posts") |> RethinkDB.Connection.run(conn)

    {:ok, conn: conn}
  end

  test "get, insert and update queries work" do
    {:ok, test_model} = TestRepo.insert(%TestModel{title: "yay"})
    from_db = TestRepo.get(TestModel, test_model.id)
    assert test_model == from_db

    # update_changeset = TestRepo.changeset(from_db, %{title: "yayay"})
    # {:ok, updated_model} = TestRepo.update(update_changeset)
    # assert updated_model.title == "yayay"
  end

  # test "respect schema" do
  #   {:error, changeset} = TestRepo.insert(%TestModel{blablabla: "yay"})
  #   assert changeset.errors == "blablabla"
  # end

  test "insert queries with Ecto.Date should work" do
    date = Ecto.Date.utc
    {:ok, test_model} = TestRepo.insert(%TestModel{date: date})
    assert test_model.date == date
  end

  test "insert queries with Ecto.DateTime should work" do
    date = Ecto.DateTime.utc
    {:ok, test_model} = TestRepo.insert(%TestModel{date: date})
    assert test_model.date == date
  end
end
