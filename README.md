# RethinkDB Ecto

Shim library to make it easy to use RethinkDB with Ecto. This is not a full Ecto adapter. It allows using Changesets and validations and callbacks. It basically enables Ecto.Model only.

Still very Proof of Concept. Feedback wanted.

Examples:

instead of:
```elixir
def MyConnection do
  use RethinkDB.Connection
end
```

do:

```elixir
def MyConnection do
  use RethinkDB.Ecto.Connection
end
```

and then use it like:

```elixir
p = MyConnection.get(Post, 1)

changeset = Post.changeset(p, %{title: "cool stuff"})

MyConnection.update(changeset)

MyConnection.delete(p)

MyConnection.all(Post)

p = %Post{title: "boring stuff"}

MyConnection.insert(p)


query = table("posts") |>
	filter(fn (post) ->
	  post[:title] != "boring stuff" || post[:author] == "Greg"
	end)

MyConnection.query(Post, query)

```
