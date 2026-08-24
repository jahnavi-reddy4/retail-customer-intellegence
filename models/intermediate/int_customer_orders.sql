/*
  Customer purchase sequencing. Window functions:
  order_seq numbers each customer's purchases in time; first/last order dates
  come from min/max over the partition; lag() gives the gap between consecutive
  orders, which feeds both cohort logic and the churn features.
*/
with orders as (
    select * from {{ ref('int_orders') }}
    where is_return_order = false
      and order_value > 0
)

select
    customer_id,
    invoice,
    order_date,
    order_value,
    row_number() over (partition by customer_id order by order_date)  as order_seq,
    min(order_date)  over (partition by customer_id)                  as first_order_date,
    max(order_date)  over (partition by customer_id)                  as last_order_date,
    datediff('day',
        lag(order_date) over (partition by customer_id order by order_date),
        order_date)                                                  as days_since_prev_order
from orders
