"""
AI decision-support proof of concept.
Important: this is a portfolio prototype, not a production autonomous scheduler.
"""
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder
from sklearn.impute import SimpleImputer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import roc_auc_score, accuracy_score

df = pd.read_csv("data/raw/vyorius_drone_operations_synthetic_2021_2026.csv")
truth = lambda s: s.astype(str).str.lower().isin(["yes","true","1"])

# 1) Predictive maintenance
features = [
    "manufacturer","drone_model","platform_type","battery_health_pct","charge_cycles",
    "days_since_last_service","mission_distance_km","mission_duration_min","payload_utilization_pct"
]
X=df[features]
y=truth(df["maintenance_due"]).astype(int)
cat=[c for c in features if X[c].dtype=="object"]
num=[c for c in features if c not in cat]
pre=ColumnTransformer([
    ("cat",Pipeline([("impute",SimpleImputer(strategy="most_frequent")),
                    ("encode",OneHotEncoder(handle_unknown="ignore"))]),cat),
    ("num",Pipeline([("impute",SimpleImputer(strategy="median"))]),num)
])
model=Pipeline([("prep",pre),("model",RandomForestClassifier(
    n_estimators=180,max_depth=10,class_weight="balanced",random_state=42,n_jobs=-1))])
Xtr,Xte,ytr,yte=train_test_split(X,y,test_size=.2,random_state=42,stratify=y)
model.fit(Xtr,ytr)
p=model.predict_proba(Xte)[:,1]
print("Predictive-maintenance ROC-AUC:",round(roc_auc_score(yte,p),3))
print("Predictive-maintenance accuracy:",round(accuracy_score(yte,model.predict(Xte)),3))

# 2) AI-assisted mission scheduling risk score
# Use only information a planner could know before launch.
sched=df[[
    "mission_id","drone_id","mission_date","mission_start_time","manufacturer","mission_type",
    "battery_health_pct","battery_start_pct","wind_speed_mps","signal_strength_pct","gps_accuracy_m",
    "payload_utilization_pct","maintenance_due","days_since_last_service","operator_experience_years"
]].copy()
sched["maintenance_risk"]=truth(sched["maintenance_due"]).astype(int)
sched["risk_score"]=100*(
    .22*np.clip(sched["wind_speed_mps"]/15,0,1)+
    .18*np.clip((85-sched["signal_strength_pct"])/40,0,1)+
    .14*np.clip((sched["gps_accuracy_m"]-.5)/2.5,0,1)+
    .14*np.clip((90-sched["battery_health_pct"])/30,0,1)+
    .08*np.clip((80-sched["battery_start_pct"])/50,0,1)+
    .08*np.clip(sched["payload_utilization_pct"]/100,0,1)+
    .10*np.clip(sched["days_since_last_service"]/120,0,1)+
    .06*sched["maintenance_risk"]
)
sched["recommendation"]=pd.cut(
    sched["risk_score"],[-1,25,45,100],
    labels=["Schedule first","Review conditions","Defer / reassign"]
)
sched.sort_values("risk_score").to_csv("data/processed/ai_schedule_recommendations.csv",index=False)
print("\nSaved AI schedule recommendations.")
