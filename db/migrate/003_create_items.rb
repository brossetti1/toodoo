class CreateItems < ActiveRecord::Migration
    def up
      create_table :items do |i|
        i.integer :list_id
        i.string :name
        i.datetime :due_date
        i.boolean :finished, default: false
        i.timestamps
      end
    end
       
    def down
      drop_table :items
    end
  end