class ReservationsController < ApplicationController

  before_action :set_reservation, only: [:show, :edit, :update, :destroy, :activa, :enProceso, :finalizada, :cancelada]
  load_and_authorize_resource

  def index
    @reservationsActivas = Reservation.activas_proceso
    @updateStateProceso = Reservation.validates_hour_start(Reservation.all)
    @updateStateFinalizada = Reservation.validates_hour_finish(Reservation.all)

    if @updateStateProceso.is_a?(Array)
      gon.reserve_id = nil
    else
      gon.reserve_id = @updateStateProceso
    end

    unless @updateStateFinalizada.nil? or @updateStateFinalizada[0].equal?(0)
        query_finally = Reservation.where('id = ?', @updateStateFinalizada)
        query_finally.each do |q|
          r_id = q.reserve_price_id
          name_and_value = ReservePrice.joins(:console).where('reserve_prices.id = ?', r_id).select("consoles.name, reserve_prices.value")
          gon.console_name = name_and_value.pluck(:name)
          gon.reserve_price_value = name_and_value.pluck(:value)
        end
    end
  end

  def generate_pdf
    @search = Report.new(params[:search])
    @reservations_to_pdf = @search.search_date_reservations
    @date_from = @search.date_from.to_date
    @date_to = @search.date_to.to_date
    respond_to do |format|
      format.html
      format.pdf do
        pdf=ReservationPdf.new(@reservations_to_pdf,@date_from,@date_to)
        send_data pdf.render, filename: 'reservas.pdf',disposition: "inline",type: 'application/pdf'
      end
    end
  end

  def generate_chart
    @search = Report.new(params[:search])
    @products_to_pdf = @search.search_date_products
    @date_from = @search.date_from.to_date
    @date_to = @search.date_to.to_date
    @element = "Reservas"
    @verb = "registradas"
    @element_by_query = "Reserva"
    redirect_to url_for(:controller => :reports, :action => :generate_chart, :param1 => @date_from, :param2 => @date_to, :param3 =>@element, :param4 => @verb, :param5 => @element_by_query)
  end

  def ajaxnewconsole
    @console_identify = params[:consol]
    @query = ReservePrice.select("reserve_prices.id, reserve_prices.time").where('console_id = ?', @console_identify)
    @query_pluck = @query.pluck(:id, :time)
    @query_final = @query_pluck.map { |i, t| [ i, t ] }
    respond_to do |format|
      format.json { render json: @query_final }
    end
  end

  def reservations_end
    @reservations_end = Reservation.end_cancel_reservations
  end

  def change_state
    @respons = params[:respuesta]
    @id = params[:id]
    unless @respons.nil?
      if @respons.to_i == 1
        @identify = @id.to_i
        @r = Reservation.where(id: @identify).update_all(state: 'enProceso')
      elsif @respons.to_i == 3
        @identify = @id.to_i
        @r = Reservation.where(id: @identify).update_all(state: 'cancelada')
      end
    end
  end

  def show
  end

  def new
    @reservation = Reservation.new
    @reserve_prices = ReservePrice.all
    gon.console_id = 0
  end

  def edit
  end

  def create
    @reservation = Reservation.create(reservation_params)
    respond_to do |format|
      if @reservation.save
         format.json { head :no_content }
         format.js {  flash[:notice] = "¡Reserva creada satisfactoriamente!" }
      else
        format.json { render json: @reservation.errors.full_messages,status: :unprocessable_entity }
      end
    end
  end


  def update
    respond_to do |format|
      if @reservation.update(reservation_params)
        format.json { head :no_content }
        format.js {  flash[:notice] = "¡Reserva actualizada satisfactoriamente!" }
      else
        format.json { render json: @reservation.errors.full_messages,status: :unprocessable_entity }
      end
    end
  end


  def destroy
    @reservation.destroy
    respond_to do |format|
      format.html { redirect_to reservations_url, notice: 'Reservation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  #Métodos para los estados de la reserva.
  def activa
     @reservation.activa!
     redirect_to reservations_url
  end

  def enProceso
     @reservation.enProceso!
     redirect_to reservations_url
  end

  def finalizada
     @reservation.finalizada!
     redirect_to reservations_url
  end

  def cancelada
    @update_price = Reservation.cancel_reserve(Reservation.find(params[:id]), Time.now)
    @reservation.cancelada!
    redirect_to reservations_url
  end

  def reserve_ajax
    @reserve_price_reserve = ReservePrice.find(params[:id_reserve_price_selected])
    respond_to do |format|
      format.json {render json: @reserve_price_reserve}
    end
  end

  def ajaxscripts
    respond_to do |format|
      format.js {render 'scripts.js.erb'}
    end
  end

  private

    def set_reservation
      @reservation = Reservation.find(params[:id])
    end

    def reservation_params
      params.require(:reservation).permit(:date, :start_time, :console_id,:end_time, :state, :customer, :reserve_price_id)
    end

end
