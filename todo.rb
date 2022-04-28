# don't use both "completed" and "complete" for identifiers; choose one and
# stick to it to avoid annoying typos

require "sinatra"
# require "sinatra/reloader" if development? # or use 'unless production?' # moved to configure blk
require "sinatra/content_for"
require "tilt/erubis"

# 'mode' will indicate whether session or db persisance is used # move to configure blk ?
db_mode = true
require_relative (db_mode ? "database" : "session") << "_persistence"

# enable sessions
configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

# configure the development enviro
configure(:development) do
  require "sinatra/reloader"
  also_reload (db_mode ? "database" : "session") << "_persistence.rb"
end


# helpers should accept a Todo obj as input; sim to instance
# methods of a Todo class
helpers do
  # determine whether all todo items w/i a list are complete
  def all_complete?(list, mode)
    # p list # for debug
    # p mode # for debug
    mode ?
      (list[:todos_count] > 0 && list[:todos_remaining] == 0) :
      # (todos_count(list) > 0 && list[:todos].all? { |todo| todo[:complete] }) # alt
      (todos_count(list) > 0 && todos_remaining(list) == 0)
 end

  # rtn a str identifying the CSS class of a list (Todo obj)
  def list_class(list, mode)
    "complete" if all_complete?(list, mode)
  end

  # determine the number of todo items in a list (Todo obj)
  def todos_count(list)
    list[:todos].size
  end

  # count the number of incomplete todo items w/i a list (Todo obj)
  def todos_remaining(list)
    list[:todos].count { |todo| !todo[:complete] }
  end

  # rtn a str displaying the number of remaining and total number of todo items
  def todo_counts(list, mode)
    mode ?
      "#{list[:todos_remaining]} / #{list[:todos_count]}" :
      "#{todos_remaining(list)} / #{todos_count(list)}"
  end

  # sort some lists based on whether all list items are complete, while
  # saving the original ndx position
  def sort_lists(lists, mode, &blk)
    # separate the lists into a groups (hashes) of incomplete and completed lists
    # hashes are ordered for R. versions >= 1.9
    complete_lists, incomplete_lists = lists.partition { |list| all_complete?(list, mode) }
    # since we are only passing the list and not its ndx, we can yield the blk directly
    incomplete_lists.each(&blk)
    complete_lists.each(&blk)
  end

  # sort todos based on whether the todos are complete, while
  # saving the original ndx position
  def sort_todos(todos, &blk)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:complete] }
    # since we are only passing the todo item and not its ndx, we can yield the blk directly
    incomplete_todos.each(&blk)
    complete_todos.each(&blk)
  end
end

# retrieve a list w/ a specific id
def load_list(id)
  # look thru the session to find a list w/ the spec'd id
  # list = session[:lists].find { |list| list[:id] == id } # moved to SessionPersistence

  # the storage obj holds all data for our ap;
  # it is an instance of the SessionPersistence class
  list = @storage.find_list(id)

  return list if list
  session[:error] = "The specified list was not found"
  redirect "/lists"
end

# rtn an err msg if the new list name is invalid; otherwise, rtn nil
def err_for_list_name(name)
  # if session[:lists].any? { |list| list[:name] == name }
  if @storage.all_lists.any? { |list| list[:name] == name }
    'The list name must be unique'
  elsif !(1..50).cover?(name.size)
    'The list name must have between 1 and 50 characters'
  # else
  #   nil # don't explicitly need this, but it's good to show intent
  end
end

# rtn an err msg if the todo is invalid; otherwise, rtn nil
# Note: alt syntax req'd if todos must be unique
def err_for_todo(name)
# def err_for_todo(todos, name) # alt syntax
  # if todos.any? { |todo| todo[:name] == name }
  #   'The todo must be unique'
  # elsif !(1..50).cover?(name.size)
  #   'The todo must have between 1 and 50 characters'
  # end
  unless (1..50).cover?(name.size)
    'The todo must have between 1 and 50 characters'
  end
end

# rtn a specific list of todo items; equiv to
# @todos = @mode ? @storage.find_todos(@list_id) : @list[:todos]
def get_todos(data_store, id, list, mode)
  mode ? data_store.find_todos(id) : list[:todos]
end

# gen a unique id # moved to SessionPersistence
# def next_id(items)
#   max = items.map { |item| item[:id] }.max || 0
#   max + 1
# end

before do
  # make sure the user session at least contains an empty arr if there are
  # no list items
  # session[:lists] ||= [] # moved to SessionPersistence#initialize

  @storage =
    db_mode ? DatabasePersistence.new(logger) : SessionPersistence.new(session)

  # could move
  #   @list = ...
  #   @list_id = ...
  # to here
end

not_found do
  redirect "/lists"
end

get "/" do
  redirect "/lists"
end

# view list of lists (Todo objs)
get "/lists" do
  # example:
  # @lists = [
  #   { name: "Lunch Groceries", todos: [] },
  #   { name: "Dinner Groceries", todos: [] }
  # ]
  # @lists = session[:lists]
  @mode = db_mode
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# render the new list form
get "/lists/new" do
  # add a new list (Todo obj) to the session
  # session[:lists] << { name: "New List", todos: [] }
  # redirect "/lists"
  erb :new_list, layout: :layout
end

# create a new list (Todo obj)
post "/lists" do
  list_name = params[:list_name].strip # could use a fn for this

  error = err_for_list_name(list_name)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    erb :new_list, layout: :layout
  else
    # create the new list, display a success msg, and redirect
    # id = next_id(session[:lists]) # gen an id for the new list # moved to SessionPersistence
    # session[:lists] << { id: id, name: list_name, todos: [] } # moved to SessionPersistence
    @storage.create_new_list(list_name)

    session[:success] = 'The list has been created'
    redirect "/lists"
  end
end

# view a specific list (Todo obj)
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i # could use a fn for this
  @list = load_list(@list_id)
  @mode = db_mode
  @todos = get_todos(@storage, @list_id, @list, @mode)
  erb :specific_list, layout: :layout
end

# edit an existing list (Todo obj)
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# update an existing list (Todo obj)
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  list_name = params[:list_name].strip
  error = err_for_list_name(list_name)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    @mode = db_mode
    @todos = get_todos(@storage, @list_id, @list, @mode)
    erb :specific_list, layout: :layout
  else
    # update the list, display a success msg, and redirect
    # Note: we are manipulating data inside a specific list; this changes session data
    # (@list comes from load_list(), which finds a list w/i the session)
    # @list[:name] = list_name # moved to SessionPersistence
    @storage.update_list_name(@list_id, list_name)

    session[:success] = 'The list name has been updated'
    # redirect "/lists/:list_id" # surprisingly, this doesn't work (list_id must be a str) ...
    # redirect "/lists/#{@list_id}" # ... but this does (@list_id is an int)
    redirect "/lists/#{@list_id}"
  end
end

# delete an existing list (Todo obj) using POST
# (although 'get "/lists/:list_id/delete"' works, it's safer to use POST for deletion)
# Note: the posted solution uses 'destroy' rather than 'delete'
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  # unless session[:lists].reject! { |list| list[:id] == @list_id } # moved to SessionPersistence
  unless @storage.delete_list(@list_id)
    # display an err msg and re-render the form to allow err correction
    session[:error] = 'Could not delete list'
    erb :edit_list, layout: :layout
  else
    # chk to see whether the req was sent over AJAX
    if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest" # an AJAX req
      # rtn a str indicating where we want to redirect
      "/lists"
    else
      # display a success msg, and redirect
      session[:success] = 'The list has been deleted'
      redirect "/lists"
    end
  end
end

# create a todo item and add it to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  text = params[:todo].strip
  # error = err_for_todo(list[:todos], text) # only req'd if todos must be unique
  error = err_for_todo(text)
  if error
    # display an err msg and re-render the form to allow err correction
    session[:error] = error
    @mode = db_mode
    @todos = get_todos(@storage, @list_id, @list, @mode)
    erb :specific_list, layout: :layout
  else
    # create the new todo item, display a success msg, and redirect
    # id = next_id(@list[:todos]) # gen an id for the new todo item # moved to SessionPersistence
    # @list[:todos] << { id: id, name: text, complete: false } # moved to SessionPersistence
    @storage.create_new_todo(@list_id, text)

    session[:success] = 'The todo was added'
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo item from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @todo_id = params[:todo_id].to_i
  # unless @list[:todos].reject! { |todo| todo[:id] == @todo_id } # moved to SessionPersistence
  unless @storage.delete_todo(@list_id, @todo_id)
    # display an err msg and re-render the form to allow err correction
    session[:error] = 'Could not delete todo'
    @mode = db_mode
    @todos = get_todos(@storage, @list_id, @list, @mode)
    erb :specific_list, layout: :layout
  else
    # chk to see whether the req was sent over AJAX
    if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest" # an AJAX req
      status 204 # success but no content rtn'd
    else # std form submission
      # display (flash) a success msg, and redirect
      session[:success] = 'The todo has been deleted'
      redirect "/lists/#{@list_id}"
    end
  end
end

# mark a todo item in a list as complete/incomplete
post "/lists/:list_id/todos/:todo_id" do
  # get the value of the :complete flag, display a success msg, and redirect
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @todo_id = params[:todo_id].to_i
  is_complete = params[:complete] == 'true'
  # @todo = @list[:todos].find { |todo| todo[:id] == @todo_id } # moved to SessionPersistence
  # @todo[:complete] = is_complete # moved to SessionPersistence
  @storage.update_todo_status(@list_id, @todo_id, is_complete)

  session[:success] = "The todo is #{is_complete ? 'complete' : 'incomplete'}"
  redirect "/lists/#{@list_id}"
end

# mark all todo items in a list as complete
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  # @list[:todos].each { |todo| todo[:complete] = true } # moved to SessionPersistence
  @storage.mark_all_todos_complete(@list_id)

  session[:success] = "All todos have been completed"
  redirect "/lists/#{@list_id}"
end

after do
  @storage.disconnect if db_mode
end
