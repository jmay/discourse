class CreateForumsAgain < ActiveRecord::Migration
  def change
    create_table :forums do |t|
      t.string :title, null: false
      t.string :slug
      t.timestamps
    end
  end
end
