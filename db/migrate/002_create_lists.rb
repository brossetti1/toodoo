class CreateLists < ActiveRecord::Migration

  def up
    create_table :lists do |t|
      t.integer :user_id
      t.string :title
      t.timestamps
    end
  end

  def down
    drop_table :lists
  end
end
