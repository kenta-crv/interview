class AddHomepageFeaturedLocaleToDeals < ActiveRecord::Migration[6.1]
  def up
    add_column :deals, :homepage_featured_locale, :string
    add_index :deals, :homepage_featured_locale, unique: true, where: "homepage_featured_locale IS NOT NULL"

    execute <<~SQL.squish
      UPDATE deals
      SET homepage_featured_locale = CASE WHEN language = 'en' THEN 'en' ELSE 'ja' END
      WHERE homepage_featured = true
    SQL
  end

  def down
    remove_index :deals, :homepage_featured_locale
    remove_column :deals, :homepage_featured_locale
  end
end
