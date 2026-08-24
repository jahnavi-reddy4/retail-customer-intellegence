/*
  Lifetime value. Note the two guards: a 30-day floor on lifespan stops
  short-history customers producing absurd annualised frequencies (6 orders in
  a day would otherwise imply 2000+/year), and a cap of 52 keeps frequency
  within one-purchase-a-week sanity. Both were added after spotting the blow-up
  in the raw output.
*/
with co as (
    select * from {{ ref('int_customer_orders') }}
),

agg as (
    select
        customer_id,
        count(distinct invoice)                           as orders,
        sum(order_value)                                  as total_revenue,
        avg(order_value)                                  as avg_order_value,
        datediff('day', min(order_date), max(order_date)) as lifespan_days
    from co
    group by customer_id
),

scored as (
    select *, greatest(lifespan_days, 30) as lifespan_days_floored
    from agg
)

select
    customer_id,
    orders,
    round(total_revenue, 2)                               as historical_clv,
    round(avg_order_value, 2)                             as avg_order_value,
    least(round(orders / (lifespan_days_floored / 365.0), 2), 52)         as annual_frequency,
    round(avg_order_value * least(orders / (lifespan_days_floored / 365.0), 52), 2) as predicted_annual_clv
from scored
