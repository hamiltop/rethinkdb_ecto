defmodule MigrationTest do
  use ExUnit.Case

  @table_name "test_table"

  defmodule CreateTableMigrationTest do
    use Ecto.Migration
    def change do
      create table(:test_table)
    end
  end

  defmodule CreateTablePrefixMigrationTest do
    use Ecto.Migration
    def change do
      create table(:test_table, prefix: :other_test)
    end
  end

  setup_all do
    Application.put_env(:rethinkdb_ecto_test, TestRepo, [
      database: "first_test",
      hostname: "127.0.0.1",
      port: 28015,
      auth_key: ""
    ])
    {:ok, _} = TestRepo.start_link
    RethinkDB.Query.db_create(:first_test) |> TestRepo.run
    RethinkDB.Query.table_create(:schema_migrations) |> TestRepo.run
    RethinkDB.Query.db_create(:other_test) |> TestRepo.run
    on_exit fn ->
      {:ok, _pid} = TestRepo.start_link
      RethinkDB.Query.db_create(:first_test) |> TestRepo.run
      RethinkDB.Query.db_drop(:other_test) |> TestRepo.run
      TestRepo.stop
    end
    :ok
  end

  test "create and drop table" do
    Ecto.Migrator.up(TestRepo, 1, CreateTableMigrationTest, [])
    %RethinkDB.Record{data: data} = RethinkDB.Query.table_list |> TestRepo.run
    assert Enum.find(data, &(&1 == @table_name)), "#{@table_name} not found in #{inspect data}"
    Ecto.Migrator.down(TestRepo, 1, CreateTableMigrationTest, [])
    %RethinkDB.Record{data: data} = RethinkDB.Query.table_list |> TestRepo.run
    assert Enum.find(data, &(&1 == @table_name)) == nil
  end

  test "create and drop table with db prefix" do
    Ecto.Migrator.up(TestRepo, 1, CreateTablePrefixMigrationTest, [])
    %RethinkDB.Record{data: data} = RethinkDB.Query.table_list |> TestRepo.run(%{db: :other_test})
    assert Enum.find(data, &(&1 == @table_name))
    Ecto.Migrator.down(TestRepo, 1, CreateTablePrefixMigrationTest, [])
    %RethinkDB.Record{data: data} = RethinkDB.Query.table_list |> TestRepo.run(%{db: :other_test})
    assert Enum.find(data, &(&1 == @table_name)) == nil
  end
end
