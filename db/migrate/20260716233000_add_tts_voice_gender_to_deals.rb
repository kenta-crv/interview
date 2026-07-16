class AddTTSVoiceGenderToDeals < ActiveRecord::Migration[6.1]
  def change
    add_column :deals, :tts_voice_gender, :string, null: false, default: 'female'
  end
end
