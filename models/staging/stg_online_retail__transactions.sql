with source as (
    select * from {{ source('retail', 'online_retail') }}
),

cleaned as (
    select
        invoice,
        stock_code,
        trim(description)                                          as description,
        quantity,
        invoice_date,
        price,
        customer_id,
        country,
        case when left(invoice, 1) = 'C' then true else false end as is_cancellation,
        quantity * price                                          as line_revenue
    from source
    -- Data-quality decisions (each of these is deliberate):
    where customer_id is not null      -- customer-level analysis needs an identifiable customer
      and price > 0                    -- drop zero/negative-price rows
      and quantity <> 0                -- drop zero-quantity rows
      -- strip non-product line items so they don't pollute revenue
      and upper(stock_code) not in ('POST','DOT','M','MANUAL','BANK CHARGES',
                                    'AMAZONFEE','ADJUST','TEST001','TEST002','C2','GIFT')
      and not (upper(coalesce(description,'')) like '%TEST%')
)

select * from cleaned
