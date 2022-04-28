require "pg"

# the DatabasePersistence class encapsulates all of the interactions w/ the session ...
# want move any refs to the session to this class
# (including anything that sets a value in the session)
class DatabasePersistence # @storage is an instance of this class

  # def initialize(session)
    # @session = session
    # @session[:lists] ||= []
  # end
  def initialize(logger)
    # create a connection to the db # should use PG::Connection.new ???
    # @db = PG.connect(dbname: "todos")
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger # use the Sinatra logging routines
  end

  # log our query to the console and call exec_params, rtn'ing a PG::result obj
  def query(sql_statement, *params)
    # puts "#{sql_statement} #{params}"
    @logger.info "#{sql_statement} #{params}"
    @db.exec_params(sql_statement, params)
  end

  # fetch a single list from the db
  # this is really just a special-case version of all_lists()
  def find_list(list_id)
    # @session[:lists].find { |list| list[:id] == id }
    # all_lists.find { |list| list[:id] == list_id }

    # sql = "SELECT * FROM lists WHERE id = $1;"
    sql = <<~SQL
            SELECT lists.*, count(todos.id) AS todos_count,
              count(NULLIF(todos.complete, true)) AS todos_remaining
            FROM lists LEFT OUTER JOIN todos ON lists.id = todos.list_id
            WHERE lists.id = $1 -- limit result to a single list
            GROUP BY lists.id;
            -- ORDER BY lists.name; # n/r since only one list
    SQL
    result = query(sql, list_id)

    # convert the db result obj to the format used by the rest of the ap
    tuple = result.first # there is only a single row in the result set
    # { id: tuple["id"].to_i, name: tuple["name"], todos: [] } # need to fix the :todos value
    # list_id = tuple["id"].to_i # list_id is already known from the find_list method arg value !
    # { id: list_id, name: tuple["name"], todos: find_todos(list_id) }

    # try to match the format of the rtn'd hsh w/ that from all_lists()
    # add the missing keys: todos_count and todos_remaining
    # {
    #   id: list_id, # tuple["id"].to_i
    #   name: tuple["name"],
    #   # instead of :todos being inside the list obj, use a separate @todos instance var in the routes
    #   # todos: find_todos(list_id), # for consistency w/ all_lists(), remove this from the rtn'd hsh
    #   todos_count: tuple["todos_count"].to_i,
    #   todos_remaining: tuple["todos_remaining"].to_i
    # }
    tuple_to_list_hash(tuple)
  end

  # rtn all of the lists in the db
  def all_lists
    # @session[:lists]

    # sql = "SELECT * FROM lists;"
    # only query the data that we need to render the page
    # replace N+1 queries w/ a single query
    sql = <<~SQL
            SELECT lists.*, count(todos.id) AS todos_count,
              count(NULLIF(todos.complete, true)) AS todos_remaining
            FROM lists LEFT OUTER JOIN todos ON lists.id = todos.list_id
            GROUP BY lists.id
            ORDER BY lists.name;
    SQL
    result = query(sql)

    # convert the db result obj to the format used by the rest of the ap
    result.map do |tuple|
      # { id: tuple["id"], name: tuple["name"], todos: [] } # need to fix the :todos value
      # { id: tuple["id"].to_i, name: tuple["name"], todos: todos_result }
      # list_id = tuple["id"].to_i
      # { id: list_id, name: tuple["name"], todos: find_todos(list_id) } # find_todos queries each list

      # {
      #   id: tuple["id"].to_i,
      #   name: tuple["name"],
      #   todos_count: tuple["todos_count"].to_i,
      #   todos_remaining: tuple["todos_remaining"].to_i
      # }
      tuple_to_list_hash(tuple)
    end # rtn an arr of hshes
  end

  def create_new_list(list_name)
    # list_id = next_id(all_lists) # gen an id for the new list
    # all_lists << { id: list_id, name: list_name, todos: [] }

    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_list(list_id)
    # all_lists.reject! { |list| list[:id] == list_id }

    # the following line is only req'd if there's no ON DELETE CASCADE
    # condition attached to todos.list_id
    # query("DELETE FROM todos WHERE list_id = $1;", list_id)
    sql = "DELETE FROM lists WHERE id = $1;"
    query(sql, list_id)
  end

  def update_list_name(list_id, list_name)
    # list = find_list(list_id) # @list becomes find_list(id)
    # list[:name] = list_name

    sql = "UPDATE lists SET name = $2 WHERE id = $1;"
    query(sql, list_id, list_name)
  end

  def create_new_todo(list_id, todo_name)
    # list = find_list(list_id) # @list becomes find_list(id)
    # todo_id = next_id(list[:todos]) # gen an id for the new todo item
    # list[:todos] << { id: todo_id, name: todo_name, complete: false }

    sql = "INSERT INTO todos (name, list_id) VALUES ($2, $1);"
    query(sql, list_id, todo_name)
  end

  def delete_todo(list_id, todo_id)
    # list = find_list(list_id) # @list becomes find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }

    # although this works ...
    # sql = "DELETE FROM todos WHERE id = $1;"
    # query(sql, todo_id)
    # ... this is better
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, status)
    # list = find_list(list_id) # @list becomes find_list(list_id)
    # todo = list[:todos].find { |toodoo| toodoo[:id] == todo_id } # avoid var shadowing
    # todo[:complete] = status

    sql = "UPDATE todos SET complete = $3 WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id, status)
  end

  def mark_all_todos_complete(list_id)
    # list = find_list(list_id) # @list becomes find_list(list_id)
    # list[:todos].each { |todo| todo[:complete] = true }

    sql = "UPDATE todos SET complete = true WHERE list_id = $1;"
    query(sql, list_id)
  end

  # rtn all of the todo items in a specific list
  def find_todos(list_id)
    todos_sql = "SELECT * FROM todos WHERE list_id = $1;"
    todos_result = query(todos_sql, list_id)
    todos_result.map do |todo_tuple|
      # recall that SELECT returns str results; should cast result to desired datatypes
      {
        id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        complete: todo_tuple["complete"] == "t"
      }
    end
  end

  def disconnect
    @db.close
  end

  private

  # def next_id(items) # n/r when using auto-incr'ing id cols in a db
  #   max = items.map { |item| item[:id] }.max || 0
  #   max + 1
  # end

  # rtn a hsh of the tuple elems that are req'd to display a webpage
  def tuple_to_list_hash(tuple)
    {
      id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining: tuple["todos_remaining"].to_i
    }
  end
end
