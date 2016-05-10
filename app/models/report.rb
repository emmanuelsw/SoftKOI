class Report
  attr_reader :date_from, :date_to

  def initialize(params)
    params ||={}
    @date_from = parsed_date(params[:date_from], Date.today.strftime('%d/%m/%Y').to_s)
    @date_to = parsed_date(params[:date_to], Date.today.strftime('%d/%m/%Y').to_s)
  end

  def search_date_products
    Product.where('created_at BETWEEN ? AND ?',@date_from,@date_to)
  end

  def search_date_outputproducts
    OutputProduct.where('created_at BETWEEN ? AND ?',@date_from,@date_to).order(created_at: :desc )#.group('product_id').sum('stock')
  end

  def search_date_inputproducts
    InputProduct.where('created_at BETWEEN ? AND ?',@date_from,@date_to).order(created_at: :desc )#.group('product_id')
  end

  def search_date_customers
    Customers.where('created_at BETWEEN ? AND ?',@date_from,@date_to)
  end
  private
  def parsed_date(date_string, default)
    DateTime.parse(date_string)
  rescue ArgumentError, TypeError
    default
  end
end
