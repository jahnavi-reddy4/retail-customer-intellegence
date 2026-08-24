with txns as (
    select * from {{ ref('stg_online_retail__transactions') }}
)

select
    invoice,
    customer_id,
    country,
    min(invoice_date)              as order_date,
    sum(line_revenue)              as order_value,
    boolor_agg(is_cancellation)    as is_return_order
from txns
group by invoice, customer_id, country
