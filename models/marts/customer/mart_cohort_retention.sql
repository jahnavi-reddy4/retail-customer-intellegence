--Retention matrix built entirely in SQL: cohort = month of first purchase,
  --  then active customers by months-since-first, divided by the cohort's size.
with orders as (
    select * from {{ ref('int_customer_orders') }}
),

customer_cohort as (
    select
        customer_id,
        date_trunc('month', first_order_date)  as cohort_month,
        date_trunc('month', order_date)        as order_month
    from orders
),

matrix as (
    select
        cohort_month,
        datediff('month', cohort_month, order_month) as months_since_first,
        count(distinct customer_id)                  as active_customers
    from customer_cohort
    group by cohort_month, months_since_first
),

cohort_size as (
    select cohort_month, active_customers as cohort_size
    from matrix
    where months_since_first = 0
)

select
    m.cohort_month,
    m.months_since_first,
    m.active_customers,
    cs.cohort_size,
    round(m.active_customers::float / cs.cohort_size, 4) as retention_rate
from matrix m
join cohort_size cs on m.cohort_month = cs.cohort_month
order by m.cohort_month, m.months_since_first
