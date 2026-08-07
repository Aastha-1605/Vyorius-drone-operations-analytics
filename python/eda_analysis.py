"""
Vyorius Drone Operations Analytics
Run from the repository root:
    python python/eda_analysis.py
"""
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

DATA = Path("data/raw/vyorius_drone_operations_synthetic_2021_2026.csv")
OUT = Path("data/processed")
IMG = Path("images")
OUT.mkdir(parents=True, exist_ok=True)
IMG.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA, parse_dates=["mission_date"])
print("Shape:", df.shape)
print("Date range:", df["mission_date"].min().date(), "to", df["mission_date"].max().date())
print("\nMissing values (%):")
print((df.isna().mean()*100).sort_values(ascending=False).head(10))

# Core KPIs
kpis = {
    "Total Missions": len(df),
    "Mission Success Rate %": (df["mission_status"].eq("Completed").mean()*100),
    "Failure Rate %": (df["mission_status"].eq("Failed").mean()*100),
    "Delay Rate %": (df["mission_status"].eq("Delayed").mean()*100),
    "Unique Drones": df["drone_id"].nunique(),
    "Unique Customers": df["customer_id"].nunique(),
    "Average Battery Health %": df["battery_health_pct"].mean(),
    "Revenue INR": df["revenue_inr"].sum(),
    "Gross Margin INR": df["gross_margin_inr"].sum(),
    "Gross Margin %": df["gross_margin_inr"].sum()/df["revenue_inr"].sum()*100,
}
print("\nCORE KPIs")
for k,v in kpis.items():
    print(f"{k}: {v:,.2f}" if isinstance(v,(float,np.floating)) else f"{k}: {v:,}")

# Monthly business trend
df["month"] = df["mission_date"].dt.to_period("M").astype(str)
monthly = df.groupby("month").agg(
    missions=("mission_id","count"),
    revenue_inr=("revenue_inr","sum"),
    active_customers=("customer_id","nunique"),
    success_rate=("mission_status", lambda s:(s=="Completed").mean()*100)
).reset_index()
monthly.to_csv(OUT/"monthly_trends.csv", index=False)

# Problem 1: Which vendors are most reliable?
vendor = df.groupby("manufacturer").agg(
    missions=("mission_id","count"),
    success_rate=("mission_status",lambda s:(s=="Completed").mean()*100),
    avg_battery_health=("battery_health_pct","mean"),
    downtime_hours=("downtime_hours","sum"),
    revenue_inr=("revenue_inr","sum"),
    gross_margin_inr=("gross_margin_inr","sum"),
).reset_index()
vendor.to_csv(OUT/"manufacturer_performance.csv",index=False)
print("\nVendor performance:\n",vendor.sort_values("success_rate",ascending=False))

# Problem 2: What causes failures and delays?
drivers = (df[df["mission_status"].isin(["Failed","Delayed"])]
           .groupby(["mission_status","failure_reason"]).size()
           .reset_index(name="events").sort_values("events",ascending=False))
drivers.to_csv(OUT/"failure_delay_reasons.csv",index=False)
print("\nTop failure/delay drivers:\n",drivers.head(12))

# Problem 3: Which industries drive revenue?
industry = df.groupby("customer_industry").agg(
    missions=("mission_id","count"),
    revenue_inr=("revenue_inr","sum"),
    gross_margin_inr=("gross_margin_inr","sum"),
    avg_rating=("customer_rating","mean")
).reset_index()
industry["margin_pct"]=industry["gross_margin_inr"]/industry["revenue_inr"]*100
industry.to_csv(OUT/"industry_performance.csv",index=False)

# Example chart
monthly["month_dt"]=pd.to_datetime(monthly["month"])
plt.figure(figsize=(10,5))
plt.plot(monthly["month_dt"],monthly["revenue_inr"]/1e6)
plt.title("Monthly Revenue Trend")
plt.ylabel("Revenue (INR million)")
plt.grid(alpha=.2)
plt.tight_layout()
plt.savefig(IMG/"monthly_revenue_from_script.png",dpi=160)
plt.show()
