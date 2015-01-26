require "toodoo/version"
require "toodoo/init_db"
require 'highline/import'
require 'pry'


####validate dates in due_date and change due_date



module Toodoo
  class User < ActiveRecord::Base
    validates :name,  presence: true
    has_many :lists
  end

  class List < ActiveRecord::Base 
    belongs_to :user
    has_many :items
  end

  class Item < ActiveRecord::Base
    belongs_to :list
    validates :finished, inclusion: { in: [true, false] }
  end
end

class TooDooApp
  attr_reader :user, :todos, :show_done

  def initialize
    @user = nil
    @todos = nil
    @show_done = nil 
  end

  def new_user
    say("Creating a new user:")
    name = ask("Username?") { |q| q.validate = /\A\w+\Z/ }
    @user = Toodoo::User.create(:name => name)
    say("We've created your account and logged you in. Thanks #{@user.name}!")
  end

  def login
    choose do |menu|
      menu.prompt = "Please choose an account: "

      Toodoo::User.find_each do |u|
        menu.choice(u.name, "Login as #{u.name}.") { @user = u }
      end

      menu.choice("Just kidding, back to main menu!", :back) do
        say "You got it!"
        @user = nil
      end
    end
  end

  def confirm_input(selected_name, option = "delete")
    choices = 'yn'
    delete = ask("Are you *sure* you want to #{option} #{selected_name}?") do |q|
      q.validate =/\A[#{choices}]\Z/
      q.character = true
      q.confirm = true
    end
  end

  def delete_user
    delete = confirm_input("TooDoo", "stop using")
    if delete == 'y'
      @user.destroy
      @user = nil
    end
  end

  def new_todo_list
    list_title = ask("whats would you like to name this list?  ") { |q| q.validate = /[[:alpha:]]/ }
    @todos = Toodoo::List.create :user_id => @user.id, :title => list_title
    say("we have created a new to do list called #{:title}")
    # TODO: This should create a new todo list by getting input from the user.
    # The user should not have to tell you their id.
    # Create the todo list in the database and update the @todos variable.
  end

  def pick_todo_list
    puts "Which list do you want to edit? "
    choose do |menu|
      @user.lists.find_each do |list|
        menu.choice(list.title, "Which list do you want to edit?") {@todos = list}
      end 
      # TODO: This should get get the todo lists for the logged in user (@user).
      # Iterate over them and add a menu.choice line as seen under the login method's
      # find_each call. The menu choice block should set @todos to the todo list.
      #@todos = choice

      menu.choice("Just kidding, back to the main menu!", :back) do
        say "You got it!"
        @todos = nil
      end
    end
  end

  def delete_todo_list
    choose do |menu|
      menu.prompt = "which list do you want to delete? "
      @user.lists.find_each do |list|
        menu.choice("Which list do you want to edit?", list.title) {@todos = :list}
      end
      delete = confirm_input(@todos.title)
      #choices = 'yn'
      #delete = ask("Are you *sure* you want to delete #{@todos.title}?") do |q|
      #  q.validate =/\A[#{choices}]\Z/
      #  q.character = true
      #  q.confirm = true
      #end
      if delete == 'y'
        @todos.destroy
        @todos = nil
      end
    end
    # TODO: This should confirm that the user wants to delete the todo list.
    # If they do, it should destroy the current todo list and set @todos to nil.
  end

  def new_task
    item_details = {}
    item_details[:name] = ask("what do you want to name this task?") { |q| q.validate = /[[:alnum:]]/ }
    query_due_date = ask("do you want to assign a due date? 1) Yes 2) No", Integer) { |q| q.in = 1..2}
    if query_due_date == 1
      item_details[:due_date] = ask("assign a date in yyyy/mm/dd format please ", Date) { 
        |q| q.default = Time.now.strftime("%Y/%m/%d")}
      #  q.validate = '/(0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])[- \/.](19|20)\d\d/';
      #  q.validate = Date.strptime(q, '%m/%d/%Y');#lambda { |p| Date.parse(p) >= Date.today };
      #  q.responses[:not_valid] = "Enter a date greater than or equal to today" }
    else
      item_details[:due_date] = nil
    end

    Toodoo::Item.create :list_id => @todos.id, :name => item_details[:name], :due_date => item_details[:due_date]
    say("hey we successfully added a new task on #{@todos.title}")
    # TODO: This should create a new task on the current user's todo list.
    # It must take any necessary input from the user. A due date is optional.
  end

  def find_item(edit_type)
    puts "which task would you like to #{edit_type}"
    choose do |menu|
        @todos.items.each do |item|
          menu.choice(item.name, "which item do you want to change?") {return item}
      end
    end
  end


  ## NOTE: For the next 3 methods, make sure the change is saved to the database.
  def mark_done
    item = find_item("mark finished")
    binding.pry
    item.finished = true
    item.save
    # TODO: This should display the todos on the current list in a menu
    # similarly to pick_todo_list. Once they select a todo, the menu choice block
    # should update the todo to be completed.
  end


  def change_due_date
    item = find_item("mark finished")
    if item.due_date
      new_date = ask("the current due date is #{item.due_date}, pass a new date in yyyy/mm/dd format please ", Date) { 
                    |q| q.default = Time.now.strftime("%Y/%m/%d")}
    else
      new_date = ask("pass a due date in yyyy/mm/dd format please ", Date) { 
                    |q| q.default = Time.now.strftime("%Y/%m/%d")}
    end
    item.due_date = new_date
    item.save
    # TODO: This should display the todos on the current list in a menu
    # similarly to pick_todo_list. Once they select a todo, the menu choice block
    # should update the due date for the todo. You probably want to use
    # `ask("foo", Date)` here.
  end

  def edit_task
    choose do |menu|
      menu.prompt = "Which task do you want to edit "
      @todos.items.find_each do |item|
        menu.choice("Pick a task to edit", item.name) { item }
        item_title = ask("what do you want to change the task name,#{task.name}, to?") { |q| q.validate = /[[:alnum:]]/ }
        item.name = item_title
        item.save
    # TODO: This should display the todos on the current list in a menu
    # similarly to pick_todo_list. Once they select a todo, the menu choice block
    # should change the name of the todo.
      end
    end
  end

  def show_overdue
    
    # TODO: This should print a sorted list of todos with a due date *older*
    # than `Date.now`. They should be formatted as follows:
    # "Date -- Eat a Cookie"
    # "Older Date -- Play with Puppies"
  end

  def run
    puts "Welcome to your personal TooDoo app."
    loop do
      choose do |menu|
        #menu.layout = :menu_only
        #menu.shell = true
        # Are we logged in yet?
        unless @user
          menu.choice("Create a new user.", :new_user) { new_user }
          menu.choice("Login with an existing account.",:login) { login }
        end

        # We're logged in. Do we have a todo list to work on?
        if @user && !@todos
          menu.choice("Delete the current user account.",:delete_account) { delete_user }
          menu.choice("Create a new todo list.", :new_list) { new_todo_list }
          menu.choice("Work on an existing list.",:pick_list) { pick_todo_list }
          menu.choice("Delete a todo list.",:remove_list,) { delete_todo_list }
        end

        # Let's work on some todos!
        if @todos
          menu.choice("Add a new task.", :new_task) { new_task }
          menu.choice("Mark a task finished.",:mark_done) { mark_done }
          menu.choice("Change a task's due date.", :move_date) { change_due_date }
          menu.choice("change a task's description.", :edit_task) { edit_task }
          menu.choice("Toggle display of items you've finished.", :show_done) { @show_done = !!@show_done }
          menu.choice("Show a list of task's that are overdue, oldest first.", :show_overdue) { show_overdue }
          menu.choice("Go work on another Toodoo list!", :back) do
            say "You got it!"
            @todos = nil
          end
        end

        menu.choice("Quit!", :quit) { exit }
      end
    end
  end
end



#class CreateLists < ActiveRecord::Migration
#  def up
#    create_table :lists do |t|
#      t.integer :user_id
#      t.string :title
#      t.timestamps
#    end
#  end
#
#  def down
#    drop_table :lists
#  end
#end
#
#class CreateItems < ActiveRecord::Migration
#  def up
#    create_table :items do |i|
#      i.integer :list_id
#      i.string :name
#      i.datetime :due_date
#      i.boolean :finished, default: false
#      i.timestamps
#    end
#  end
#     
#  def down
#    drop_table :items
#  end
#end
#
#class CreateUsers < ActiveRecord::Migration
#  def self.up
#    create_table :users do |t|
#      t.string :name
#      t.timestamps
#    end
#  end
#
#  def self.down
#    drop_table :users
#  end
#end


binding.pry

todos = TooDooApp.new
todos.run
