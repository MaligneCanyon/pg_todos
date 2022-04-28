# the SessionPersistence class encapsulates all of the interactions w/ the session ...
# want move any refs to the session to this class
# (including anything that sets a value in the session)
class SessionPersistence # @storage is an instance of this class
  def initialize(session)
    @session = session
    @session[:lists] ||= [] # can't use all_lists here
  end

  def find_list(list_id)
    # @session[:lists].find { |list| list[:id] == id }
    all_lists.find { |list| list[:id] == list_id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    list_id = next_id(all_lists) # gen an id for the new list
    all_lists << { id: list_id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    all_lists.reject! { |list| list[:id] == list_id }
  end

  def update_list_name(list_id, list_name)
    list = find_list(list_id)
    list[:name] = list_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    list_id = next_id(list[:todos]) # gen an id for the new todo item
    list[:todos] << { id: list_id, name: todo_name, complete: false }
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, status)
    list = find_list(list_id)
    todo = list[:todos].find { |toodoo| toodoo[:id] == todo_id } # avoid var shadowing
    todo[:complete] = status
  end

  def mark_all_todos_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:complete] = true }
  end

  private

  def next_id(items)
    max = items.map { |item| item[:id] }.max || 0
    max + 1
  end
end
