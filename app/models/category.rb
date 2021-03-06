class Category < ActiveRecord::Base

	include AASM

	belongs_to :type_product
	has_many :products

	#Actualizar a "false" el "can_change" de los productos asociados
	after_save do
		if self.can_change == false
			products.update_all can_change: false
		end
	end

	validates :name,presence: true, uniqueness: true
	validates :type_product_id, presence: true
	validates :state, presence: true
	validates :description, presence: true, length: { in: 8..80 }
	before_create :set_date
	before_update :set_updated_at


	#Seleccionar Categorías disponibles
	scope :activos, -> { where(state: "disponible")}


	aasm column: "state" do

		state :disponible, :initial => true
		state :noDisponible


		event :disponible do
			transitions from: :noDisponible, to: :disponible
		end

		event :noDisponible do
			transitions from: :disponible, to: :noDisponible
		end
	end

	def self.validate_change_state

	end

	private

	def set_date
		self.created_at = Time.now.in_time_zone("Bogota")
		self.updated_at = Time.now.in_time_zone("Bogota")
	end

	def set_updated_at
		self.updated_at = Time.now.in_time_zone("Bogota")
	end


end
