class AddPresentationCtaToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :presentation_cta_label, :string, null: false, default: "契約を進める"
    add_column :deals, :presentation_cta_url, :string
    add_column :deals, :exit_contract_label, :string, null: false, default: "契約へ進む"
    add_column :deals, :exit_sales_call_label, :string, null: false, default: "担当者と商談を希望"
  end
end
