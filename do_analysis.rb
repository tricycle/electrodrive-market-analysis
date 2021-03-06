require 'rubygems'
require "csv"
require 'yaml'
require 'mysql'
require 'pp'
require 'dbi'

def first_value(set)
  return 0 if set.num_rows == 0
  set.each do |r|
    return r[0]
  end
end

def asset(condition)
  raise Error unless condition
end

mysql = Mysql.init()
mysql.connect('mysql.trikeapps.com', "elec_analysis", "ieFae5yi", "electrodrive_analysis", 3306)

#the result set has multiple months of sales data across a few years, so we need to rescale to have a projection for one year
num_months = first_value(mysql.query("SELECT (DATEDIFF(max(STR_TO_DATE(order_date, '%m/%d/%Y')),min(STR_TO_DATE(order_date, '%m/%d/%Y'))) / 30.5) FROM sales WHERE LENGTH(order_date) > 0 AND state = 'VIC'")).to_f

regions = mysql.query("SELECT DISTINCT(region_name) FROM electrodrive_regions ORDER BY LEFT(region_code,1)")


should_sell = {}
regions.each_hash do |region|
  product_name = nil
  region_name = region["region_name"]
  should_sell[region_name] = {}
  products = mysql.query("SELECT DISTINCT(model) FROM sales")
  products.each_hash do |product|
    product_name = product["model"]
    should_sell[region_name][product_name] = 0
    segments = mysql.query("SELECT DISTINCT(segment_name) FROM electrodrive_segments")
    segments.each_hash do |segment|
      segment_name = segment["segment_name"]
      
      number_of_employees_result = mysql.query(
        "SELECT `sum(employees)` FROM region_segment_employees WHERE region_name = '#{region_name}' AND segment_name = '#{segment_name}' LIMIT 1"
      ) 
      print '-'
      coefficient_result = mysql.query(
        "SELECT coefficient_per_thousand FROM product_coefficients WHERE segment_name = '#{segment_name}' AND model = '#{product_name}' LIMIT 1"
      )
      print '/'
      coefficient_number = first_value(coefficient_result).to_f
      number_of_employees = first_value(number_of_employees_result).to_f
      
      should_sell[region_name][product_name] += (coefficient_number * (number_of_employees.to_i / 1000) / num_months * 12)      
    end
  end 
  puts "Finished #{region_name}" 
end

pp should_sell

mysql.query("TRUNCATE TABLE projected_sales")

should_sell.each do |region_name, products| 
  products.each do |product, number|
    query = "INSERT INTO projected_sales VALUES ('#{region_name}','#{product}',#{number})"
    puts query
    mysql.query(query)
  end
end






