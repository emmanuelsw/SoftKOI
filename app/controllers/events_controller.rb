class EventsController < ApplicationController
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  after_action :day_of_event, only:[:index]
  # after_action :day_of_event, only:[:create]

  # GET /events
  # GET /events.json
  def index
    @events = Event.all
    @event = Event.new
  end

  # GET /events/1
  # GET /events/1.json
  def show
  end

  # GET /events/new
  def new
    @event = Event.new
  end

  # GET /events/1/edit
  def edit
  end

  # POST /events
  # POST /events.json
  def create
    @event = Event.new(event_params)

    respond_to do |format|
      if @event.save
        format.html { redirect_to @event, notice: 'Se ha creado el evento satisfactoriamente' }
        format.json { render :show, status: :created, location: @event }
      else
        format.html { render :new }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_event
    @event = Event.create(event_params)
    respond_to do |format|
      if @event.save
        format.html {redirect_to events_path,notice: 'Evento creado satisfactoriamente.'}
      else
        format.html {redirect_to events_path,notice: '¡Error al crear el evento!'}
      end
    end
  end

  def day_of_event
    unless @events.nil?
      @events.each do |event|
      #  if event.start_time.strftime("%F") == Date.today.strftime("%F")
           event.create_activity key: 'tiene un evento', read_at: nil
      # end
       end
     end
  end

  # PATCH/PUT /events/1
  # PATCH/PUT /events/1.json
  def update
    respond_to do |format|
      if @event.update(event_params)
        format.html { redirect_to @event, notice: 'El evento ha sido actualizado.' }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit }
        format.json { render json: @event.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.json
  def destroy
    @event.destroy
    respond_to do |format|
      format.html { redirect_to events_url, notice: 'Event was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event
      @event = Event.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def event_params
      params.require(:event).permit(:description, :start_time)
    end
end