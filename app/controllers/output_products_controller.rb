class OutputProductsController < ApplicationController

  load_and_authorize_resource

  def index
    @output_products = OutputProduct.all.order(created_at: :desc)
    @search = Report.new(params[:search])
  end


  def new
    #Obtener el producto que se selecciono para la baja
    @productx = Product.find(params[:product_id])
    @output_product = @productx.output_products.build
    @product = Product.activos
  end

  def generate_pdf
    @search = Report.new(params[:search])
    @outputproducts_to_pdf = @search.search_date_outputproducts
    @date_from = @search.date_from.to_date
    @date_to = @search.date_to.to_date
    respond_to do |format|
      format.html
      format.pdf do
        pdf=OutputproductPdf.new(@outputproducts_to_pdf,@date_from,@date_to)
        send_data pdf.render, filename: 'salida_productos.pdf',disposition: "inline",type: 'application/pdf'
      end
    end
  end

  def generate_chart
    @search = Report.new(params[:search])
    @products_to_pdf = @search.search_date_products
    @date_from = @search.date_from.to_date
    @date_to = @search.date_to.to_date
    @element = "Salida de productos"
    @verb = "registradas"
    @element_by_query = "Salida"
    redirect_to url_for(:controller => :reports, :action => :generate_chart, :param1 => @date_from, :param2 => @date_to, :param3 =>@element, :param4 => @verb, :param5 => @element_by_query)
  end


  def create
    @output_product = Product.new
    @output_product = OutputProduct.new(output_product_params)
    @output_product.product = params[:stock]
    respond_to do |format|
      if @output_product.save
        format.html { redirect_to products_path, notice: 'La salida se ha registrado correctamente' }
        format.json { render :index, status: :created, location: @output_product }
      else
        format.html { render :new }
        format.json { render json: @output_product.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_output_product
    @output_product = OutputProduct.find(params[:id])
  end

  def output_product_params
    params.require(:output_product).permit(:stock, :product_id)
  end
end
