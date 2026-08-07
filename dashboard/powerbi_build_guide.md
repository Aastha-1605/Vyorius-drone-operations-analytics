# Power BI Build Guide — Vyorius Drone Operations

## Recommended report structure

### Page 1 — Executive Command Center
Use a dark navy header, white canvas, teal accent and amber warning color.

**KPI cards**
- Total Missions
- Mission Success Rate
- Revenue
- Gross Margin %
- Unique Drones
- Maintenance Due Rate

**Visuals**
- Line chart: Date → Revenue / MRR Proxy
- Clustered bar: Manufacturer → Mission Success Rate
- Bar: Customer Industry → Revenue
- Donut: Mission Status distribution
- Bar: Failure Reason → Failed/Delayed event count
- Filled map: State/City → Revenue or Missions

**Slicers**
Year, Quarter, Manufacturer, Drone Model, Industry, Subscription Plan, Mission Type.

### Page 2 — Fleet & Maintenance Intelligence
- Matrix: Drone ID, Manufacturer, Model, Missions, Success Rate, Battery Health, Downtime, Maintenance Cost, Gross Margin
- Scatter: Battery Health vs Charge Cycles; size = Maintenance Cost; legend = Manufacturer
- Bar: Downtime by Manufacturer
- Column: Maintenance Due Rate by Model
- Table: Top 20 high-risk drones / maintenance exceptions
- Add conditional formatting on Battery Health and Downtime.

### Page 3 — Mission Reliability & Root Cause
- Success / Failure / Delay cards
- Failure reason Pareto chart
- Weather condition vs Failure Rate
- Wind-speed band vs Success Rate
- GPS Accuracy vs Signal Strength scatter
- Mission Type vs Success Rate
- Drill-through to mission-level detail.

### Page 4 — Customer & Commercial Analytics
- Revenue by Industry
- Revenue by Subscription Plan
- Customer retention proxy by year
- Revenue per customer
- Gross margin by industry
- Rating by industry/plan
- Top customers table

### Page 5 — AI Decision Support
- Predictive maintenance risk table
- Feature-importance bar chart
- AI schedule risk distribution
- Recommended schedule-priority table
- Fleet optimization scorecard

## Hover / tooltip design
Power BI charts already show values on hover. For richer hover:
1. Create a new page and set **Page information → Tooltip = On**.
2. Set canvas type to **Tooltip**.
3. Add small cards: Missions, Success Rate, Revenue, Battery Health, Downtime.
4. Add Manufacturer, Model, Mission Type as context.
5. Select a source visual → Format → General → Tooltip → Report page → choose the tooltip page.

## Data model
Create a Date table:
```DAX
Date =
ADDCOLUMNS(
    CALENDAR(MIN(drone_operations[mission_date]), MAX(drone_operations[mission_date])),
    "Year", YEAR([Date]),
    "Month", FORMAT([Date],"YYYY-MM"),
    "Month Name", FORMAT([Date],"MMM"),
    "Quarter", "Q" & FORMAT([Date],"Q")
)
```
Relate Date[Date] (1) → drone_operations[mission_date] (*).

## Theme
Suggested portfolio palette:
- Navy: #102A43
- Teal: #1F8A8A
- Amber: #F6A23A
- Alert red: #D64545
- Off-white: #F5F7FA
- Slate text: #66788A

Use 16:9 page size, 8–12 px rounded cards, minimal gridlines, and no more than 6 KPI cards per page.

## Dashboard preview
See `images/powerbi_dashboard_preview.png`.

## Important metric caveat
The dataset contains mission-level revenue, but no subscription billing invoice table. Therefore **MRR Proxy** is a monthly revenue trend, not audited MRR.
