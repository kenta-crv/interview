class AddDocumentKindToDealDocuments < ActiveRecord::Migration[6.1]
  def change
    add_column :deal_documents, :document_kind, :string, null: false, default: "proposal"
    add_index :deal_documents, [:deal_id, :document_kind]
  end
end
