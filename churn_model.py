"""
Churn model for the retail customer-intelligence project.

"""
import os
import pandas as pd
import snowflake.connector
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, confusion_matrix, classification_report

conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    role="TRANSFORMER",
    warehouse="TRANSFORMING_WH",
    database="ANALYTICS",
)

query = """
select
    r.customer_id,
    r.recency_days,
    r.frequency,
    r.monetary,
    c.avg_order_value,
    c.annual_frequency,
    case when r.recency_days > 90 then 1 else 0 end as churned  -- 90d ~ 3x typical cycle
from analytics.dbt_dev_retail_marts.mart_rfm r
join analytics.dbt_dev_retail_marts.mart_clv c using (customer_id)
"""
df = pd.read_sql(query, conn)
df.columns = [c.lower() for c in df.columns]
print(f"Loaded {len(df):,} customers | churn rate {df['churned'].mean():.3f}")

# recency deliberately excluded - it defines the label (leakage)
features = ["frequency", "monetary", "avg_order_value", "annual_frequency"]
X, y = df[features], df["churned"]

X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)
scaler = StandardScaler()
model = LogisticRegression(max_iter=1000)
model.fit(scaler.fit_transform(X_tr), y_tr)

probs = model.predict_proba(scaler.transform(X_te))[:, 1]
print(f"ROC-AUC: {roc_auc_score(y_te, probs):.3f}")
print(classification_report(y_te, model.predict(scaler.transform(X_te))))
print(pd.DataFrame({"feature": features, "coef": model.coef_[0]})
      .sort_values("coef", key=abs, ascending=False).to_string(index=False))

df["churn_probability"] = model.predict_proba(scaler.transform(df[features]))[:, 1]
df[["customer_id", "churn_probability"]].to_csv("seeds/churn_scores.csv", index=False)
print(f"Wrote seeds/churn_scores.csv ({len(df):,} customers)")
conn.close()
