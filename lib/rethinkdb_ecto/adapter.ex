defmodule RethinkDB.Ecto.Adapter do
  @behaviour Ecto.Adapter.Storage

  import RethinkDB.Connection
  import RethinkDB.Query
  alias RethinkDB.Response
  alias RethinkDB.Record

  def storage_up(opts) do
    db = Dict.fetch!(opts, :database)
    # TODO: add host and port
    {:ok, pid} = RethinkDB.Connection.start_link([])
    result = db_create(db) |> run(pid)
    case result do
      %Response{data: %{"e" => 4100000, "r" => r}} ->
        already_exists = "Database `#{db}` already exists."
        case r do
          [^already_exists] -> {:error, :already_up}
          _ -> {:error, r}
        end
      %Record{data: %{"dbs_created" => 1}} -> :ok
    end
  end

  def storage_down(opts) do
    db = Dict.fetch!(opts, :database)
    # TODO: add host and port
    {:ok, pid} = RethinkDB.Connection.start_link([])
    result = db_drop(db) |> run(pid)
    case result do
      %Response{data: %{"e" => 4100000, "r" => r}} ->
        does_not_exist = "Database `#{db}` does not exist."
        case r do
          [^does_not_exist]-> {:error, :already_down}
          _ -> {:error, r}
        end
      %Record{data: %{"dbs_dropped" => 1}} -> :ok
    end
  end

  def execute_ddl(repo, {:create_if_not_exists, %Ecto.Migration.Table{name: name}, _fields}, _opts) do
    db(repo.config[:database]) |> table_create(name) |> run(repo)
    :ok
  end

  def execute_ddl(repo, {:create, e = %Ecto.Migration.Table{name: name}, fields}, opts) do
    options = e.options || %{}
    database = e.prefix || repo.config[:database]
    db(database) |> table_create(name, options) |> run(repo)
    :ok
  end

  def execute_ddl(repo, {:create, %Ecto.Migration.Index{columns: [column], table: table}}, _opts) do
    db(repo.config[:database]) |> table(table) |> index_create(column) |> run(repo)
    :ok
  end

  def execute_ddl(repo, {:drop, e = %Ecto.Migration.Table{name: name}}, opts) do
    database = e.prefix || repo.config[:database]
    db(database) |> table_drop(name) |> run(repo)
    :ok
  end

  def execute_ddl(repo, {:drop_if_exists, %Ecto.Migration.Index{columns: [column], table: table}}, _opts) do
    db(repo.config[:database]) |> table(table) |> index_drop(column) |> run(repo)
    :ok
  end

  def supports_ddl_transaction?, do: false
end
