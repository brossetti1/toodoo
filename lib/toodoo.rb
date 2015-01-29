require "toodoo/version"
require "toodoo/init_db"
require 'highline/import'
require 'pry'
require 'date'


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
  attr_reader :user, :todos

  def initialize
    @user = nil
    @todos = nil
  end

  def clear
    `clear`
    puts "\n\n\n"
  end

  def new_user
    clear
    say "\nCreating a new user:"
    name = ask("Username?") { |q| q.validate = /\A\w+\Z/ }
    @user = Toodoo::User.create(:name => name)
    say "\nWe've created your account and logged you in. Thanks #{@user.name}!"
  end

  def login
    choose do |menu|
      menu.prompt = "Please choose an account: "

      Toodoo::User.find_each do |u|
        menu.choice(u.name, "Login as #{u.name}.") { @user = u }
      end

      menu.choice("back to main menu!", :back) do
        say "\nYou got it!"
        @user = nil
      end
    end
  end

  def confirm_input(selected_name, option = "delete")
    choices = 'yn'
    delete = ask("Are you *sure* you want to #{option} #{selected_name}? select 'y' or 'n'") do |q|
      q.validate =/\A[#{choices}]\Z/
      q.character = true
      q.responses[:not_valid] = "you must select 'y' or 'n'."
    end
    delete
  end

  def delete_user
    delete = confirm_input("user", "delete")
    if delete == 'y'
      @user.destroy
      @user = nil
    end
  end

  def new_todo_list
    list_title = ask("whats would you like to name this list?  ") { |q| q.validate = /[[:alpha:]]/ }
    Toodoo::List.create :user_id => @user.id, :title => list_title
    say "\nwe have created a new to do list called #{:title}"
    @user.lists.find_each {|list| @todos = list if list.title == list_title}
  end

  def pick_todo_list
    say "\nWhich list do you want to edit? "
    choose do |menu|
      @user.lists.find_each do |list|
        menu.choice(list.title, "Which list do you want to edit?") {@todos = list}
      end 
      menu.choice("back to the main menu!", :back) do
        say "\nYou got it!"
        @todos = nil
      end
    end
  end

  def delete_todo_list
    say "\nWhich list do you want to delete?"
    choose do |menu|
      @user.lists.find_each do |list|
        menu.choice(list.title, "pick a list to delete.") {@todos = list}
      end
        menu.choice("back to the main menu!", :back) do
        say "\nYou got it!"
        @todos = nil
      end
    end
    binding.pry
    delete = confirm_input(@todos.title)
    if delete == 'y'
      @todos.destroy
      @todos = nil
    end
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
    say "\nhey we successfully added a new task on #{@todos.title}"
  end

  def find_item(edit_type)
    say "\nwhich task would you like to #{edit_type}?"
    choose do |menu|
      @todos.items.each do |item|
        menu.choice(item.name, "choose an item to #{edit_type}") {return item}
      end
      menu.choice(:back, "back to the main menu!") do
        say "\nYou got it!"
      end
    end
  end

  def mark_finished
    item = find_item("mark finished")
    if item != nil
      item.finished = true
      item.save
    end
  end

  def change_due_date
    item = find_item("change the due date of")
    if item.due_date
      new_date = ask("the current due date is #{item.due_date}, pass a new date in yyyy/mm/dd format please ", Date) { 
                    |q| q.default = Time.now.strftime("%Y/%m/%d")}
    else
      new_date = ask("pass a due date in yyyy/mm/dd format please ", Date) { 
                    |q| q.default = Time.now.strftime("%Y/%m/%d")}
    end
    item.due_date = new_date
    item.save
  end

  def edit_task
    item = find_item("edit")
    if item != nil
      item_title = ask("what do you want to change the task name, #{item.name}, to?") { |q| q.validate = /[[:alnum:]]/ }
      item.name = item_title
      item.save
    end
  end

  def show_overdue
    say "\nhere are the tasks that are overdue."
    @todos.items.where("finished = :finished AND due_date < :date AND due_date NOT NULL", 
    finished: false, date: DateTime.now).order(:due_date).reverse.each do |item|
      puts "due date: #{item.due_date.strftime("%Y-%m-%d")} -- item name: #{item.name}"
    end
    ask("\n1. back to main menu!\n", :back) {}
  end

  def show_done
    @todos.items.where(finished: true).order(:due_date).reverse.each do |item|
      if item.due_date == nil
        puts "due date: N/A -- item name: #{item.name}"
      else
        puts "due date: #{item.due_date.strftime("%Y-%m-%d")} -- item name: #{item.name}"
      end
    end
    binding.pry
    ask("\n1. back to main menu!\n", :back) {}
  end

  def run
    puts "Welcome to your personal TooDoo app."
    loop do
      choose do |menu|

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
          menu.choice("Mark a task finished.",:mark_finished) { mark_finished }
          menu.choice("Change a task's due date.", :move_date) { change_due_date }
          menu.choice("change a task's description.", :edit_task) { edit_task }
          menu.choice("Toggle display of items you've finished.", :show_done) { show_done }
          menu.choice("Show a list of task's that are overdue, oldest first.", :show_overdue) { show_overdue }
          menu.choice("Go work on another Toodoo list!", :back) do
            say "\nYou got it!"
            @todos = nil
          end
        end

        menu.choice("Quit!", :quit) { exit }
      end
    end
  end
end

binding.pry

todos = TooDooApp.new
todos.run
