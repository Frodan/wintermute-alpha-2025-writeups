#!/usr/bin/env python3
import json
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime, timedelta
from collections import Counter
import statistics

def load_blob_data():
    """Load blob data from result.json"""
    try:
        with open('result.json', 'r') as f:
            data = json.load(f)
            return data.get('blobs', [])
    except Exception as e:
        print(f"Error loading result.json: {e}")
        return []

def parse_timestamp(timestamp_str):
    """Parse timestamp string to datetime object"""
    try:
        # Handle ISO format with Z (UTC)
        if timestamp_str.endswith('Z'):
            return datetime.fromisoformat(timestamp_str[:-1])
        else:
            return datetime.fromisoformat(timestamp_str)
    except:
        return None

def calculate_gaps(blobs):
    """Calculate time gaps between consecutive blobs"""
    timestamps = []
    
    # Extract and sort timestamps
    for blob in blobs:
        timestamp = None
        # The blob has a 'time' field directly
        if 'time' in blob:
            timestamp = parse_timestamp(blob['time'])
        
        if timestamp:
            timestamps.append(timestamp)
    
    if len(timestamps) < 2:
        return []
    
    # Sort timestamps
    timestamps.sort()
    
    # Calculate gaps in seconds
    gaps = []
    for i in range(1, len(timestamps)):
        gap = (timestamps[i] - timestamps[i-1]).total_seconds()
        gaps.append(gap)
    
    return gaps, timestamps

def analyze_gaps(gaps):
    """Analyze gap patterns and identify outliers"""
    if not gaps:
        return {}
    
    gaps_array = np.array(gaps)
    
    # Basic statistics
    mean_gap = np.mean(gaps_array)
    median_gap = np.median(gaps_array)
    std_gap = np.std(gaps_array)
    
    # Identify outliers (gaps > mean + 2*std)
    outlier_threshold = mean_gap + 2 * std_gap
    outliers = gaps_array[gaps_array > outlier_threshold]
    
    # Convert to hours/minutes for readability
    mean_gap_hours = mean_gap / 3600
    median_gap_hours = median_gap / 3600
    
    return {
        'total_gaps': len(gaps),
        'mean_gap_seconds': mean_gap,
        'mean_gap_hours': mean_gap_hours,
        'median_gap_seconds': median_gap,
        'median_gap_hours': median_gap_hours,
        'std_gap_seconds': std_gap,
        'outlier_threshold': outlier_threshold,
        'outliers': outliers,
        'outlier_count': len(outliers),
        'max_gap_seconds': np.max(gaps_array),
        'min_gap_seconds': np.min(gaps_array)
    }

def create_histogram(gaps, timestamps, analysis):
    """Create timeline plot showing gaps over time"""
    plt.figure(figsize=(16, 10))
    
    # Convert gaps to hours for better readability
    gaps_hours = [gap / 3600 for gap in gaps]
    
    # Use timestamps[1:] since gaps[i] is the gap between timestamps[i] and timestamps[i+1]
    gap_timestamps = timestamps[1:]
    
    # Debug: Print gap statistics
    print(f"Gap statistics for debugging:")
    print(f"  Min gap: {min(gaps):.0f} seconds ({min(gaps_hours):.2f} hours)")
    print(f"  Max gap: {max(gaps):.0f} seconds ({max(gaps_hours):.2f} hours)")
    print(f"  Median gap: {analysis['median_gap_seconds']:.0f} seconds ({analysis['median_gap_hours']:.2f} hours)")
    print(f"  Number of gaps: {len(gaps)}")
    
    # Create scatter plot with line for normal gaps
    plt.plot(gap_timestamps, gaps_hours, 'o-', color='lightsteelblue', markersize=3, linewidth=1, alpha=0.6, label='Normal gaps')
    
    # Add median line (more stable than mean for outlier detection)
    median_hours = analysis['median_gap_hours']
    plt.axhline(median_hours, color='green', linestyle='-', linewidth=2, label=f'Median: {median_hours:.2f}h', alpha=0.9)
    
    # Highlight outliers with larger markers and annotations
    outlier_threshold = analysis['outlier_threshold']
    outliers = []
    
    for i, gap in enumerate(gaps):
        if gap > outlier_threshold:
            gap_hours = gap / 3600
            plt.scatter(gap_timestamps[i], gap_hours, color='red', s=80, zorder=5, alpha=0.9, edgecolors='darkred', linewidth=1)
            
            # Add annotation for each outlier
            plt.annotate(f'{gap_hours:.1f}h', 
                        (gap_timestamps[i], gap_hours),
                        xytext=(10, 10), textcoords='offset points',
                        bbox=dict(boxstyle='round,pad=0.3', facecolor='red', alpha=0.7),
                        fontsize=9, color='white', weight='bold',
                        arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0'))
            
            outliers.append((gap_timestamps[i], gap_hours))
            print(f"  Outlier: {gap_hours:.2f}h ({gap:.0f}s) at {gap_timestamps[i].strftime('%Y-%m-%d %H:%M')}")
    
    # Add outlier markers to legend
    if outliers:
        plt.scatter([], [], color='red', s=80, alpha=0.9, edgecolors='darkred', linewidth=1, label=f'Outliers ({len(outliers)} found)')
    
    # Force Y-axis to start from 0 and add some padding at top
    max_gap_hours = max(gaps_hours)
    plt.ylim(bottom=0, top=max_gap_hours * 1.1)
    
    # Add summary text box
    summary_text = f"""Summary:
• Total gaps analyzed: {len(gaps)}
• Median gap: {median_hours:.2f} hours
• Outliers detected: {len(outliers)}
• Largest gap: {max_gap_hours:.1f}h"""
    
    plt.text(0.02, 0.98, summary_text, transform=plt.gca().transAxes, 
             bbox=dict(boxstyle='round,pad=0.5', facecolor='lightblue', alpha=0.8), 
             verticalalignment='top', fontsize=10, fontfamily='monospace')
    
    plt.xlabel('Date', fontsize=12)
    plt.ylabel('Gap Between Blobs (hours)', fontsize=12)
    plt.title('Celestia Blob Posting Gaps Over Time\n(Red dots show abnormally long gaps)', fontsize=14, pad=20)
    plt.legend(fontsize=11)
    plt.grid(True, alpha=0.3, linestyle='--')
    
    # Format x-axis dates
    import matplotlib.dates as mdates
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
    plt.gca().xaxis.set_major_locator(mdates.DayLocator(interval=max(1, len(gap_timestamps)//15)))
    plt.xticks(rotation=45)
    
    # Improve layout
    plt.tight_layout()
    plt.savefig('blob_gap_histogram.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print(f"Chart saved. Found {len(outliers)} outliers. Largest gap: {max_gap_hours:.1f} hours")

def generate_report(blobs, gaps, timestamps, analysis):
    """Generate markdown report"""
    
    report_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Calculate posting period
    if timestamps:
        first_blob = min(timestamps)
        last_blob = max(timestamps)
        total_period = (last_blob - first_blob).total_seconds()
        total_period_days = total_period / (24 * 3600)
    else:
        first_blob = last_blob = None
        total_period_days = 0
    
    # Create timestamp to blob mapping for easy lookup
    blob_by_timestamp = {}
    for blob in blobs:
        timestamp = parse_timestamp(blob['time'])
        if timestamp:
            blob_by_timestamp[timestamp] = blob
    
    # Identify significant gaps with blob data
    significant_gaps = []
    if gaps and analysis['outliers'].size > 0:
        gap_threshold = analysis['outlier_threshold']
        for i, gap in enumerate(gaps):
            if gap > gap_threshold:
                gap_seconds = gap
                gap_hours = gap / 3600
                gap_days = gap / (24 * 3600)
                
                # Get blob data before and after the gap
                before_timestamp = timestamps[i]
                after_timestamp = timestamps[i + 1]
                before_blob = blob_by_timestamp.get(before_timestamp)
                after_blob = blob_by_timestamp.get(after_timestamp)
                
                significant_gaps.append({
                    'gap_number': i + 1,
                    'gap_seconds': gap_seconds,
                    'gap_hours': gap_hours,
                    'gap_days': gap_days,
                    'ratio_to_mean': gap / analysis['mean_gap_seconds'],
                    'before_timestamp': before_timestamp,
                    'after_timestamp': after_timestamp,
                    'before_blob': before_blob,
                    'after_blob': after_blob
                })
    
    # Generate report content
    report = f"""# Celestia Blob Posting Consistency Analysis

**Analysis Date:** {report_time}  
**Namespace:** `0000000000000000000000000000000000000000000065636c74330a`

## Executive Summary

"""
    
    if not blobs:
        report += "❌ **No blob data found** - Could not analyze posting consistency.\n\n"
    elif len(gaps) < 1:
        report += "❌ **Insufficient data** - Need at least 2 blobs to analyze consistency.\n\n"
    else:
        # Consistency assessment
        cv = analysis['std_gap_seconds'] / analysis['mean_gap_seconds']  # Coefficient of variation
        
        if cv < 0.5:
            consistency = "✅ **CONSISTENT** - Low variability in posting intervals"
        elif cv < 1.0:
            consistency = "⚠️ **MODERATELY CONSISTENT** - Some variability in posting intervals"
        else:
            consistency = "❌ **INCONSISTENT** - High variability in posting intervals"
        
        report += f"{consistency}\n\n"
        
        if analysis['outlier_count'] > 0:
            report += f"**{analysis['outlier_count']} significant gaps** detected that are much longer than usual.\n\n"
        else:
            report += "**No significant gaps** detected - posting appears regular.\n\n"
    
    report += f"""## Data Overview

- **Total Blobs:** {len(blobs)}
- **Time Gaps Analyzed:** {len(gaps)}
- **Analysis Period:** {total_period_days:.1f} days
"""
    
    if timestamps:
        report += f"""- **First Blob:** {first_blob.strftime('%Y-%m-%d %H:%M:%S')} UTC
- **Last Blob:** {last_blob.strftime('%Y-%m-%d %H:%M:%S')} UTC
"""
    
    if gaps:
        report += f"""
## Gap Statistics

- **Average Gap:** {analysis['mean_gap_seconds']:.0f} seconds ({analysis['mean_gap_hours']:.2f} hours)
- **Median Gap:** {analysis['median_gap_seconds']:.0f} seconds ({analysis['median_gap_hours']:.2f} hours)
- **Standard Deviation:** {analysis['std_gap_seconds']:.0f} seconds ({analysis['std_gap_seconds']/3600:.2f} hours)
- **Shortest Gap:** {analysis['min_gap_seconds']:.0f} seconds
- **Longest Gap:** {analysis['max_gap_seconds']:.0f} seconds ({analysis['max_gap_seconds']/3600:.2f} hours, {analysis['max_gap_seconds']/(24*3600):.1f} days)

## Consistency Analysis

**Coefficient of Variation:** {(analysis['std_gap_seconds'] / analysis['mean_gap_seconds']):.2f}
- Values < 0.5: Consistent posting
- Values 0.5-1.0: Moderately consistent
- Values > 1.0: Inconsistent posting

"""
        
        if significant_gaps:
            report += f"""## Significant Gaps Identified

**Outlier Threshold:** {analysis['outlier_threshold']:.0f} seconds ({analysis['outlier_threshold']/3600:.2f} hours)

| Gap # | Duration (seconds) | Hours | Days | Ratio to Avg | Before Time | After Time |
|-------|-------------------|-------|------|--------------|-------------|------------|
"""
            for gap in significant_gaps[:10]:  # Show top 10
                before_time = gap['before_timestamp'].strftime('%Y-%m-%d %H:%M:%S')
                after_time = gap['after_timestamp'].strftime('%Y-%m-%d %H:%M:%S')
                report += f"| {gap['gap_number']} | {gap['gap_seconds']:.0f}s | {gap['gap_hours']:.1f}h | {gap['gap_days']:.1f}d | {gap['ratio_to_mean']:.1f}× | {before_time} | {after_time} |\n"
            
            if len(significant_gaps) > 10:
                report += f"\n*... and {len(significant_gaps) - 10} more significant gaps*\n"
            
            # Add detailed blob data for the largest gaps
            report += f"""
### Detailed Blob Data for Largest Gaps

"""
            # Sort by gap size and show top 5
            largest_gaps = sorted(significant_gaps, key=lambda x: x['gap_seconds'], reverse=True)[:5]
            
            for i, gap in enumerate(largest_gaps, 1):
                report += f"""
#### Gap #{gap['gap_number']} - {gap['gap_seconds']:.0f} seconds ({gap['gap_hours']:.1f} hours)

**Gap Period:** {gap['before_timestamp'].strftime('%Y-%m-%d %H:%M:%S')} → {gap['after_timestamp'].strftime('%Y-%m-%d %H:%M:%S')} UTC

**Blob Before Gap:**
```json
{json.dumps(gap['before_blob'], indent=2) if gap['before_blob'] else 'No blob data available'}
```

**Blob After Gap:**
```json
{json.dumps(gap['after_blob'], indent=2) if gap['after_blob'] else 'No blob data available'}
```

---
"""
        else:
            report += """## Significant Gaps Identified

✅ **No significant gaps detected** - All posting intervals are within normal range (mean ± 2×std).
"""
    
    report += f"""
## Visual Analysis

![Gap Distribution](blob_gap_histogram.png)

The histogram above shows the distribution of time gaps between consecutive blob postings. 

## Conclusion

"""
    
    if not gaps:
        report += "Unable to analyze posting consistency due to insufficient data."
    elif analysis['outlier_count'] == 0:
        report += f"Blob posting appears **consistent** with an average interval of {analysis['mean_gap_seconds']:.0f} seconds ({analysis['mean_gap_hours']:.2f} hours). No significant gaps were detected."
    else:
        report += f"Blob posting shows **{analysis['outlier_count']} significant gaps** out of {len(gaps)} intervals analyzed. "
        if analysis['outlier_count'] / len(gaps) < 0.1:
            report += "Overall posting is mostly consistent with occasional longer gaps."
        else:
            report += "This indicates irregular posting patterns with frequent longer gaps."
    
    report += f"""

---
*Analysis generated on {report_time}*
"""
    
    return report

def main():
    print("Loading blob data...")
    blobs = load_blob_data()
    
    if not blobs:
        print("No blob data found. Make sure result.json exists and contains blob data.")
        return
    
    print(f"Analyzing {len(blobs)} blobs...")
    
    # Calculate gaps
    gaps_result = calculate_gaps(blobs)
    if len(gaps_result) == 2:
        gaps, timestamps = gaps_result
    else:
        gaps, timestamps = [], []
    
    if not gaps:
        print("Could not extract timestamp data from blobs.")
        return
    
    print(f"Calculated {len(gaps)} time gaps")
    
    # Analyze gaps
    analysis = analyze_gaps(gaps)
    
    # Create histogram
    print("Creating timeline plot...")
    create_histogram(gaps, timestamps, analysis)
    
    # Generate report
    print("Generating report...")
    report = generate_report(blobs, gaps, timestamps, analysis)
    
    # Save report
    with open('blob_consistency_report.md', 'w') as f:
        f.write(report)
    
    print("✅ Analysis complete!")
    print("📊 Histogram saved: blob_gap_histogram.png")
    print("📄 Report saved: blob_consistency_report.md")
    print(f"📈 Found {analysis.get('outlier_count', 0)} significant gaps")

if __name__ == "__main__":
    main()