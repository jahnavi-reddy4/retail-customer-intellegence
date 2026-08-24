--This mart intersects all three signals into a single recommended action per customer

with rfm as (
    select * from {{ ref('mart_rfm') }}
),

clv as (
    select * from {{ ref('mart_clv') }}
),

churn as (
    select
        customer_id,
        churn_probability,
        case
            when churn_probability >= 0.66 then 'High'
            when churn_probability >= 0.33 then 'Medium'
            else 'Low'
        end as churn_risk
    from {{ ref('churn_scores') }}
),

combined as (
    select
        rfm.customer_id,
        rfm.rfm_segment,
        rfm.r_score, rfm.f_score, rfm.m_score,
        clv.predicted_annual_clv,
        churn.churn_probability,
        churn.churn_risk,
        case when clv.predicted_annual_clv >= 2000 then 'High value' else 'Standard' end as value_tier
    from rfm
    join clv   on rfm.customer_id = clv.customer_id
    join churn on rfm.customer_id = churn.customer_id
),

actioned as (
    select
        *,
        case
            when value_tier = 'High value' and churn_risk = 'High' then 'Win-back (priority)'
            when value_tier = 'High value' and churn_risk = 'Low'  then 'Retain & Reward'
            when rfm_segment in ('New / Promising','Potential')    then 'Grow'
            when churn_risk = 'Medium'                             then 'Nurture'
            when churn_risk = 'High'                               then 'Win-back (low-cost)'
            else 'Maintain'
        end as recommended_action
    from combined
)

select * from actioned
