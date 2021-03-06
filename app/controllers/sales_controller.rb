class SalesController < ApplicationController

	load_and_authorize_resource
	before_action :set_penalty, only:[:index]
	before_action :limit_date_customer,only:[:index]
	before_action :delete_sales_without_payments ,only:[:index]

	def index
		@sales = Sale.all
	end

	def make_payment_index
		sale_id = params[:sale_id]
		@sale = Sale.where(id: sale_id)
		@sale.each do |sale|
			@sale = sale
		end
	end
	#Generar informe
	def generate_pdf
		@search = Report.new(params[:search])
		@sales_to_pdf = @search.search_date_sales
		@date_from = @search.date_from.to_date
		@date_to = @search.date_to.to_date
		respond_to do |format|
			format.html
			format.pdf do
				pdf=SalePdf.new(@sales_to_pdf,@date_from,@date_to)
				send_data pdf.render, filename: 'ventas.pdf',disposition: "inline",type: 'application/pdf'
			end
		end
	end

	#Generar estadisticas
	def generate_chart
		@search = Report.new(params[:search])
		@products_to_pdf = @search.search_date_sales
		@date_from = @search.date_from.to_date
		@date_to = @search.date_to.to_date
		@element = "Ventas"
		@verb = "registradas"
		@element_by_query = "Venta"
		redirect_to url_for(:controller => :reports, :action => :generate_chart, :param1 => @date_from, :param2 => @date_to, :param3 =>@element, :param4 => @verb, :param5 => @element_by_query)
	end

	# Estados
	def pago
		@sale.pago!
		redirect_to sales_url
	end

	def anulada
		@sale.anulada!
		redirect_to sales_url
	end


	def show
		set_sale
		@sale_items = Item.all.where(sale_id: @sale)
	end


	# Crear venta, asignar empleado y guardar
	def new
		@sale = Sale.new
		@sale.user_id = current_user.id
		@sale.save
		redirect_to edit_sale_path(@sale)
	end


	# Traer productos y clientes disponibles
	def edit
		if Sale.joins(:payments).where(payments: {sale_id: @sale}).empty?
			set_sale

			populate_products
			populate_customers

			@sale.items.build
			@sale.payments.build

			@custom_customer = Customer.new
		else
			respond_to do |format|
				format.html { redirect_to sales_url, alert: 'La venta no se puede editar.' }
			end
		end

	end


	# Asociar cliente a la venta
	def create_customer_association
		set_sale
		@message ="no"
		unless @sale.blank? || params[:customer_id].blank?
			@sale.customer_id = params[:customer_id]
			customer_info = Customer.where(id: @sale.customer_id)
			customer_info.each do |customer|
				if customer.state == "conDeuda"
					flash[:alert] = "El cliente tiene deudas pendientes"
				end
			end
			@sale.save
		end
		respond_to do |format|
			format.js {ajax_refresh}
		end
	end


	# Agregar productos a la venta
	def create_line_item
		set_sale
		populate_products

		existing_line_item = Item.where('product_id = ? AND sale_id = ?', params[:product_id], @sale.id).first

		if existing_line_item.blank?
			line_item = Item.new(product_id: params[:product_id], sale_id: params[:sale_id], quantity: params[:quantity])
			line_item.price = line_item.product.price
			line_item.save

			remove_item_from_stock(params[:product_id])
			update_line_item_totals(line_item)
		else
			existing_line_item.quantity += 1
			existing_line_item.save

			remove_item_from_stock(params[:product_id])
			update_line_item_totals(existing_line_item)
		end

		update_totals

		respond_to do |format|
			format.js { ajax_refresh }
		end
	end


	# Aumentar cantidad de un producto asociado
	def add_item
		set_sale
		populate_products

		line_item = Item.where(sale_id: params[:sale_id], product_id: params[:product_id]).first
		line_item.quantity += 1
		line_item.save

		# Llama método que reduce cantidad de stock
		remove_item_from_stock(params[:product_id])
		update_line_item_totals(line_item)

		update_totals

		respond_to do |format|
			format.js { ajax_refresh }
		end
	end

	#Actualizar el limit date
	def update_limit_date
		set_sale
		limit_date = params[:limit_date]

		limit_date = Date.parse(limit_date)
		@sale.limit_date = limit_date.strftime("%F")
		@sale.save
		respond_to do |format|
			format.js { ajax_refresh }
		end
	end


	# Reducir cantidad de un producto asociado o eliminarlo
	def remove_item
		set_sale
		populate_products

		line_item = Item.where(sale_id: params[:sale_id], product_id: params[:product_id]).first
		line_item.quantity -= 1

		if line_item.quantity == 0
			line_item.destroy
		else
			line_item.save
			update_line_item_totals(line_item)
		end

		# Llama método que devuelve cantidad al stock
		return_item_to_stock(params[:product_id])

		update_totals

		respond_to do |format|
			format.js { ajax_refresh }
		end
	end


	# Crear usuario nuevo
	def create_custom_customer
		set_sale
		populate_products

		respond_to do |format|
			custom_customer = Customer.new
			custom_customer.document = params[:custom_customer][:document]
			custom_customer.firstname = params[:custom_customer][:firstname]
			custom_customer.lastname = params[:custom_customer][:lastname]
			unless params[:custom_customer][:phone].nil?
				custom_customer.phone = params[:custom_customer][:phone]
			end
			unless params[:custom_customer][:cellphone].nil?
				custom_customer.cellphone = params[:custom_customer][:cellphone]
			end
			custom_customer.cellphone = params[:custom_customer][:cellphone]
			custom_customer.birthday = params[:custom_customer][:birthday]
			custom_customer.email = params[:custom_customer][:email]
			custom_customer.type_document_id = params[:custom_customer][:type_document_id]

			if custom_customer.save
				@sale.add_customer(custom_customer.id)

				update_totals
				customer_info = Customer.where(id: custom_customer.id)
			else
					flash[:alert] = "Datos incorrectos al registrar el cliente"
			end



			format.js { ajax_refresh }
		end
	end


	# Obtener valor total del producto con cantidad + -
	def update_line_item_totals(line_item)
		line_item.total_price = line_item.price * line_item.quantity
		line_item.save
	end


	# Obtener precio de venta con descuento via ajax
	def sale_discount
		@sale = Sale.find(params[:sale_discount][:sale_id])

		@sale.discount = params[:sale_discount][:discount]
		@sale.save

		update_totals

		respond_to do |format|
			format.js { ajax_refresh }
		end
	end


	# Actualizar valores de la venta (valor, valor total, descuento)
	def update_totals

		set_sale

		@sale.amount = 0

		for line_item in @sale.items
			@sale.amount += line_item.total_price
		end

		total_amount = @sale.amount

		if @sale.discount.blank?
			@sale.total_amount = total_amount
		else
			discount_amount = total_amount * @sale.discount
			@sale.total_amount = total_amount - discount_amount
		end

		@sale.save
	end


	# Agregar comentarios a la venta
	def add_comment
		set_sale
		@sale.comment = params[:sale_comments][:comment]
		@sale.save

		respond_to do |format|
			format.js { ajax_refresh }
		end
	end


	#Notificacion cuando una venta llega a su fecha limite de pago
	def limit_date_customer
		@sales.each do |sale|
			if sale.state == "sinPagar"
				if sale.limit_date.strftime("%F") < Time.now.strftime("%F")
					unless sale.customer == nil
						sale.customer.create_activity key: 'ha excedido su fecha limite de pago', read_at: nil
					end
				elsif sale.limit_date.strftime("%F") == Time.now.strftime("%F")
					unless sale.customer == nil
						sale.customer.create_activity key: 'tiene que pagar hoy', read_at: nil
					end
				end
			end
		end
	end

	private

	# Actualizar secciones de la vista de ventas
	def ajax_refresh
		render(file: 'sales/ajax_reload.js.erb')
	end

	# Identificar la venta
	def set_sale
		if @sale.blank?
			if params[:sale_id].blank?
				if params[:search].blank?
					@sale = Sale.find(params[:id])
				else
					@sale = Sale.find(params[:search][:sale_id])
				end
			else
				@sale = Sale.find(params[:sale_id])
			end
		end
	end


	# Poblar productos
	def populate_products
		@available_products = Product.active_quantity
	end


	# Poblar clientes
	def populate_customers
		@available_customers = Customer.all
	end


	# Reducir el stock de un producto
	def remove_item_from_stock(product_id)
		product = Product.find(product_id)
		if product.stock - 1 < 0
			render :json => "No hay suficientes productos"
		else
			product.stock -= 1
			product.save
		end

	end


	# Devolver producto a stock
	def return_item_to_stock(product_id)
		product = Product.find(product_id)
		product.stock += 1
		product.save
	end


	# Parametros permitidos para guardar en la venta
	def sale_params
		params.require(:sale).permit(
			:state, :amount,
			:total_amount,
			:discount,
			:limit_date,
			:user_id,
			:comment,
			:customer_id,
			items_attributes: [:id, :product_id, :price, :total_price, :quantity])
	end

	#Generar multa a una venta cuando excede la fecha limite de pago
	def set_penalty
		actually_date = DateTime.now.strftime("%F")
		@sales.each do |sale|
			if sale.state == "sinPagar"
				months = 2
				res = 0
				limit_date = sale.limit_date.strftime("%F")
				actually_date_more_30_days = sale.limit_date + 30.days
				actually_date_more_30_days_as_string = actually_date_more_30_days.strftime("%F")
				if actually_date > limit_date
					porcent = sale.total_amount * 0.1
					porcent = porcent.to_i
					if sale.penalty < porcent
						sale.update(penalty: porcent)
					end
					if actually_date >= actually_date_more_30_days_as_string
						begin
							sum_days = 30 * months
							limit_date_sum_per_months = sale.limit_date + sum_days.days
							if limit_date_sum_per_months.strftime("%F") < DateTime.now.strftime("%F")
								sale.update(penalty: porcent * months)
								months += 1
							elsif months == 2
								res = 1
								sale.update(penalty: porcent * months)
							else
								res = 1
							end
						end while res < 1
					end
				end
			end
		end
	end

	def delete_sales_without_payments
		unless @sales.nil?
			@sales.each do |sale|

				unless sale.state == "pago" && sale.state == "anulada"
					puts "#{sale.state}---------->stado"
					unless Payment.exists? sale_id: sale.id
						sale.destroy
					end
				end
			end
		end
	end

end
