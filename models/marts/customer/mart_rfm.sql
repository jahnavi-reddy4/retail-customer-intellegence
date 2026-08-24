with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

rfm_base as (
    select
        customer_id,
        datediff('day', max(order_date), date '{{ var("snapshot_date") }}') as recency_days,
        count(distinct invoice)                                             as frequency,
        sum(order_value)                                                    as monetary
    from customer_orders
    group by customer_id
),

scored as (
    select
        *,
        -- recency: fewer days = better, so invert so 5 = best
        6 - ntile(5) over (order by recency_days)  as r_score,
        ntile(5) over (order by frequency)         as f_score,
        ntile(5) over (order by monetary)          as m_score
    from rfm_base
),

segmented as (
    select
        *,
        r_score * 100 + f_score * 10 + m_score     as rfm_cell,
        case
            when r_score >= 4 and f_score >= 4                  then 'Champions'
            when r_score >= 3 and f_score >= 3                  then 'Loyal'
            when r_score >= 4 and f_score <= 2                  then 'New / Promising'
            when r_score  = 3 and f_score <= 2                  then 'Potential'
            when r_score <= 2 and f_score >= 3                  then 'At Risk'
            when r_score <= 2 and f_score <= 2 and m_score >= 3 then 'Cant Lose Them'
            when r_score <= 1                                   then 'Hibernating'
            else 'Needs Attention'
        end                                        as rfm_segment
    from scored
)

select * from segmented
