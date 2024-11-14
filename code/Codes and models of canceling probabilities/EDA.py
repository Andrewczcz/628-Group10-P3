import pandas as pd
import matplotlib.pyplot as plt
import numpy as np


d = pd.read_csv('data.csv')

# Plot cancellation rate by Carrier
cancelled_rate = d.groupby('OP_UNIQUE_CARRIER')['CANCELLED'].mean().reset_index()
cancelled_rate['CANCELLED'] *= 100
cancelled_rate = cancelled_rate.sort_values(by='CANCELLED', ascending=False)
plt.figure(figsize=(14, 6))
plt.bar(cancelled_rate['OP_UNIQUE_CARRIER'], cancelled_rate['CANCELLED'], color='skyblue', edgecolor='black', alpha=0.7)
plt.title('Cancellation Rate by Unique Carrier (Sorted)')
plt.xlabel('Unique Carrier')
plt.ylabel('Cancellation Rate (%)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

# Plot cancellation rate by holiday period
holiday_cancelled_rate = d.groupby('Holiday_Period')['CANCELLED'].mean() * 100
plt.figure(figsize=(10, 6))
holiday_cancelled_rate.plot(kind='bar', color='skyblue', edgecolor='black')
plt.title('Cancellation Rate by Holiday Period')
plt.xlabel('Holiday Period')
plt.ylabel('Cancellation Rate (%)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()



# Plot cancellation rate by top 100 destination and origin airports
fig, ax = plt.subplots(2, 1, figsize=(14, 18), sharex=False)
# Destination airport cancellation rate
dest_cancel_stats = d.groupby('DEST')['CANCELLED'].agg(['count', 'sum']).reset_index()
dest_cancel_stats.columns = ['AIRPORT_ID', 'Total_Flights', 'Cancelled_Flights']
dest_cancel_stats['Cancel_Rate'] = dest_cancel_stats['Cancelled_Flights'] / dest_cancel_stats['Total_Flights']
dest_cancel_stats = dest_cancel_stats[~dest_cancel_stats['AIRPORT_ID'].str.contains('OTHERS')]
dest_cancel_stats = dest_cancel_stats.sort_values(by='Cancel_Rate', ascending=False).head(100)
ax[0].bar(dest_cancel_stats['AIRPORT_ID'], dest_cancel_stats['Cancel_Rate'], color='skyblue')
ax[0].set_title('Top 100 Cancellation Rates by Destination Airport')
ax[0].set_xlabel('Destination Airport')
ax[0].set_ylabel('Cancellation Rate')
ax[0].tick_params(axis='x', labelrotation=90, labelsize=8)

# Origin airport cancellation rate
origin_cancel_stats = d.groupby('ORIGIN')['CANCELLED'].agg(['count', 'sum']).reset_index()
origin_cancel_stats.columns = ['AIRPORT_ID', 'Total_Flights', 'Cancelled_Flights']
origin_cancel_stats['Cancel_Rate'] = origin_cancel_stats['Cancelled_Flights'] / origin_cancel_stats['Total_Flights']
origin_cancel_stats = origin_cancel_stats[~origin_cancel_stats['AIRPORT_ID'].str.contains('OTHERS')]
origin_cancel_stats = origin_cancel_stats.sort_values(by='Cancel_Rate', ascending=False).head(100)
ax[1].bar(origin_cancel_stats['AIRPORT_ID'], origin_cancel_stats['Cancel_Rate'], color='lightgreen')
ax[1].set_title('Top 100 Cancellation Rates by Origin Airport')
ax[1].set_xlabel('Origin Airport')
ax[1].set_ylabel('Cancellation Rate')
ax[1].tick_params(axis='x', labelrotation=90, labelsize=8)
plt.tight_layout()
plt.show()

# Plot cancellation rate by time category for arrival and departure
arr_time_cancel_stats = d.groupby('ARR_CateTIME')['CANCELLED'].mean().reset_index()
arr_time_cancel_stats['CANCELLED'] *= 100  # Convert to percentage
arr_time_cancel_stats.columns = ['Time_Category', 'Arrival_Cancel_Rate']
dep_time_cancel_stats = d.groupby('DEP_CateTIME')['CANCELLED'].mean().reset_index()
dep_time_cancel_stats['CANCELLED'] *= 100  # Convert to percentage
dep_time_cancel_stats.columns = ['Time_Category', 'Departure_Cancel_Rate']
cancel_stats = pd.merge(arr_time_cancel_stats, dep_time_cancel_stats, on='Time_Category', how='outer').fillna(0)
plt.figure(figsize=(12, 6))
bar_width = 0.35
index = np.arange(len(cancel_stats['Time_Category']))
plt.bar(index, cancel_stats['Arrival_Cancel_Rate'], width=bar_width, color='skyblue', label='Arrival Cancellation Rate')
plt.bar(index + bar_width, cancel_stats['Departure_Cancel_Rate'], width=bar_width, color='lightgreen', label='Departure Cancellation Rate')
plt.title('Cancellation Rate by Time Category (Arrival and Departure)')
plt.xlabel('Time Category')
plt.ylabel('Cancellation Rate (%)')
plt.xticks(index + bar_width / 2, cancel_stats['Time_Category'], rotation=45)
plt.legend()
plt.tight_layout()
plt.show()


