class AddVisitorRegistrationSettingsToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :skip_visitor_registration, :boolean, default: false, null: false
    add_column :deals, :visitor_info_fields, :json, default: {}, null: false
  end
end
