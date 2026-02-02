/**
 * Example React/TypeScript code for integrating advanced analytics into admin panel
 * 
 * This file contains example components that can be adapted for your admin panel.
 * These examples use Next.js 14 App Router and Supabase client.
 */

import { createClient } from '@supabase/supabase-js';
import { useState, useEffect } from 'react';

// ============================================================================
// Types
// ============================================================================

interface AnalyticsDashboard {
  churn_risk: {
    critical: number;
    high: number;
    medium: number;
    low: number;
    avg_risk_score: number;
  };
  rfm_segments: Record<string, number>;
  ltv_summary: {
    total_customers: number;
    avg_ltv: number;
    total_ltv: number;
    vip_count: number;
    high_value_count: number;
  };
  recent_cohort: {
    cohort_month: string;
    cohort_size: number;
    retention_m1: number;
    retention_m3: number;
    retention_m6: number;
  };
}

interface ChurnRiskUser {
  customer_phone: string;
  risk_score: number;
  risk_level: string;
  last_order_date: string;
  days_since_last_order: number;
  total_orders: number;
  total_spent: number;
  avg_days_between_orders: number;
}

interface RFMSegment {
  customer_phone: string;
  recency_days: number;
  frequency: number;
  monetary: number;
  r_score: number;
  f_score: number;
  m_score: number;
  rfm_segment: string;
  segment_description: string;
}

interface CohortData {
  cohort_month: string;
  cohort_size: number;
  period_number: number;
  active_users: number;
  retention_rate: number;
  total_orders: number;
  total_revenue: number;
  avg_revenue_per_user: number;
}

// ============================================================================
// Example Component 1: Analytics Dashboard Overview
// ============================================================================

export function AnalyticsDashboardPage() {
  const [dashboard, setDashboard] = useState<AnalyticsDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadDashboard();
  }, []);

  async function loadDashboard() {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_analytics_dashboard');
      if (error) throw error;
      setDashboard(data);
    } catch (error) {
      console.error('Failed to load analytics dashboard:', error);
    } finally {
      setLoading(false);
    }
  }

  if (loading) return <div>Loading analytics...</div>;
  if (!dashboard) return <div>No data available</div>;

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-3xl font-bold">Analytics Dashboard</h1>

      {/* Churn Risk Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <MetricCard
          title="Critical Risk"
          value={dashboard.churn_risk.critical}
          color="red"
          description="Users about to churn"
        />
        <MetricCard
          title="High Risk"
          value={dashboard.churn_risk.high}
          color="orange"
          description="Need attention"
        />
        <MetricCard
          title="Medium Risk"
          value={dashboard.churn_risk.medium}
          color="yellow"
          description="Monitor closely"
        />
        <MetricCard
          title="Avg Risk Score"
          value={dashboard.churn_risk.avg_risk_score.toFixed(1)}
          color="blue"
          description="Overall health"
        />
      </div>

      {/* LTV Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <MetricCard
          title="Total Customers"
          value={dashboard.ltv_summary.total_customers}
          color="green"
        />
        <MetricCard
          title="Avg LTV"
          value={`₽${dashboard.ltv_summary.avg_ltv.toFixed(0)}`}
          color="green"
        />
        <MetricCard
          title="VIP Customers"
          value={dashboard.ltv_summary.vip_count}
          color="purple"
        />
      </div>

      {/* Recent Cohort Retention */}
      {dashboard.recent_cohort && (
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">
            Recent Cohort: {dashboard.recent_cohort.cohort_month}
          </h2>
          <div className="grid grid-cols-4 gap-4">
            <div>
              <p className="text-sm text-gray-500">Cohort Size</p>
              <p className="text-2xl font-bold">{dashboard.recent_cohort.cohort_size}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Month 1 Retention</p>
              <p className="text-2xl font-bold">{dashboard.recent_cohort.retention_m1}%</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Month 3 Retention</p>
              <p className="text-2xl font-bold">{dashboard.recent_cohort.retention_m3}%</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Month 6 Retention</p>
              <p className="text-2xl font-bold">{dashboard.recent_cohort.retention_m6}%</p>
            </div>
          </div>
        </div>
      )}

      {/* RFM Segments */}
      <div className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-xl font-semibold mb-4">Customer Segments (RFM)</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {Object.entries(dashboard.rfm_segments).map(([segment, count]) => (
            <div key={segment} className="border p-4 rounded">
              <p className="text-sm text-gray-500 capitalize">{segment.replace('_', ' ')}</p>
              <p className="text-2xl font-bold">{count}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// Example Component 2: Churn Risk Management
// ============================================================================

export function ChurnRiskPage() {
  const [users, setUsers] = useState<ChurnRiskUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'critical' | 'high'>('all');
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadChurnRisk();
  }, [filter]);

  async function loadChurnRisk() {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('calculate_churn_risk');
      if (error) throw error;
      
      let filtered = data as ChurnRiskUser[];
      if (filter !== 'all') {
        filtered = filtered.filter(u => u.risk_level === filter);
      }
      
      setUsers(filtered);
    } catch (error) {
      console.error('Failed to load churn risk:', error);
    } finally {
      setLoading(false);
    }
  }

  async function exportToCsv() {
    const csv = [
      ['Phone', 'Risk Score', 'Risk Level', 'Days Since Order', 'Total Orders', 'Total Spent'],
      ...users.map(u => [
        u.customer_phone,
        u.risk_score,
        u.risk_level,
        u.days_since_last_order,
        u.total_orders,
        u.total_spent
      ])
    ].map(row => row.join(',')).join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `churn_risk_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
  }

  if (loading) return <div>Loading churn analysis...</div>;

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold">Churn Risk Management</h1>
        <button
          onClick={exportToCsv}
          className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
        >
          Export to CSV
        </button>
      </div>

      {/* Filters */}
      <div className="flex gap-2">
        <button
          onClick={() => setFilter('all')}
          className={`px-4 py-2 rounded ${filter === 'all' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        >
          All ({users.length})
        </button>
        <button
          onClick={() => setFilter('critical')}
          className={`px-4 py-2 rounded ${filter === 'critical' ? 'bg-red-500 text-white' : 'bg-gray-200'}`}
        >
          Critical
        </button>
        <button
          onClick={() => setFilter('high')}
          className={`px-4 py-2 rounded ${filter === 'high' ? 'bg-orange-500 text-white' : 'bg-gray-200'}`}
        >
          High
        </button>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Phone</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Risk Score</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Level</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Days Since Order</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total Orders</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total Spent</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {users.map((user, idx) => (
              <tr key={idx}>
                <td className="px-6 py-4 whitespace-nowrap">{user.customer_phone}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`font-bold ${getRiskColor(user.risk_level)}`}>
                    {user.risk_score.toFixed(0)}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 py-1 rounded text-xs ${getRiskBadgeColor(user.risk_level)}`}>
                    {user.risk_level}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">{user.days_since_last_order}</td>
                <td className="px-6 py-4 whitespace-nowrap">{user.total_orders}</td>
                <td className="px-6 py-4 whitespace-nowrap">₽{user.total_spent}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <button className="text-blue-500 hover:underline">Send Campaign</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// ============================================================================
// Example Component 3: Cohort Retention Heatmap
// ============================================================================

export function CohortAnalysisPage() {
  const [cohorts, setCohorts] = useState<CohortData[]>([]);
  const [loading, setLoading] = useState(true);
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadCohorts();
  }, []);

  async function loadCohorts() {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('calculate_cohort_retention', {
        months_back: 12
      });
      if (error) throw error;
      setCohorts(data as CohortData[]);
    } catch (error) {
      console.error('Failed to load cohort data:', error);
    } finally {
      setLoading(false);
    }
  }

  if (loading) return <div>Loading cohort analysis...</div>;

  // Group by cohort month
  const cohortMap = cohorts.reduce((acc, row) => {
    if (!acc[row.cohort_month]) {
      acc[row.cohort_month] = { size: row.cohort_size, periods: {} };
    }
    acc[row.cohort_month].periods[row.period_number] = row.retention_rate;
    return acc;
  }, {} as Record<string, { size: number; periods: Record<number, number> }>);

  const cohortMonths = Object.keys(cohortMap).sort().reverse();
  const maxPeriod = Math.max(...cohorts.map(c => c.period_number));

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-3xl font-bold">Cohort Retention Analysis</h1>

      <div className="bg-white rounded-lg shadow overflow-x-auto">
        <table className="min-w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500">Cohort</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500">Size</th>
              {Array.from({ length: maxPeriod + 1 }, (_, i) => (
                <th key={i} className="px-6 py-3 text-center text-xs font-medium text-gray-500">
                  M{i}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {cohortMonths.map(month => (
              <tr key={month}>
                <td className="px-6 py-4 whitespace-nowrap font-medium">{month}</td>
                <td className="px-6 py-4 whitespace-nowrap">{cohortMap[month].size}</td>
                {Array.from({ length: maxPeriod + 1 }, (_, i) => {
                  const rate = cohortMap[month].periods[i];
                  return (
                    <td
                      key={i}
                      className="px-6 py-4 whitespace-nowrap text-center"
                      style={{
                        backgroundColor: rate ? getHeatmapColor(rate) : '#f3f4f6'
                      }}
                    >
                      {rate ? `${rate.toFixed(1)}%` : '-'}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="bg-blue-50 p-4 rounded">
        <p className="text-sm">
          <strong>How to read:</strong> Each row represents a cohort (users who made their first order in that month).
          Columns show retention rates for each subsequent month. Darker green = better retention.
        </p>
      </div>
    </div>
  );
}

// ============================================================================
// Helper Components and Functions
// ============================================================================

function MetricCard({
  title,
  value,
  color,
  description
}: {
  title: string;
  value: number | string;
  color?: string;
  description?: string;
}) {
  const colorClasses = {
    red: 'bg-red-50 border-red-200',
    orange: 'bg-orange-50 border-orange-200',
    yellow: 'bg-yellow-50 border-yellow-200',
    blue: 'bg-blue-50 border-blue-200',
    green: 'bg-green-50 border-green-200',
    purple: 'bg-purple-50 border-purple-200'
  };

  return (
    <div className={`p-6 rounded-lg border-2 ${colorClasses[color as keyof typeof colorClasses] || 'bg-gray-50 border-gray-200'}`}>
      <p className="text-sm text-gray-600 mb-1">{title}</p>
      <p className="text-3xl font-bold mb-1">{value}</p>
      {description && <p className="text-xs text-gray-500">{description}</p>}
    </div>
  );
}

function getRiskColor(level: string): string {
  const colors = {
    critical: 'text-red-600',
    high: 'text-orange-600',
    medium: 'text-yellow-600',
    low: 'text-green-600'
  };
  return colors[level as keyof typeof colors] || 'text-gray-600';
}

function getRiskBadgeColor(level: string): string {
  const colors = {
    critical: 'bg-red-100 text-red-800',
    high: 'bg-orange-100 text-orange-800',
    medium: 'bg-yellow-100 text-yellow-800',
    low: 'bg-green-100 text-green-800'
  };
  return colors[level as keyof typeof colors] || 'bg-gray-100 text-gray-800';
}

function getHeatmapColor(rate: number): string {
  // Green gradient based on retention rate
  if (rate >= 80) return '#166534'; // dark green
  if (rate >= 60) return '#16a34a'; // green
  if (rate >= 40) return '#4ade80'; // light green
  if (rate >= 20) return '#bbf7d0'; // very light green
  return '#f3f4f6'; // gray
}

// ============================================================================
// API Route Example (Next.js App Router)
// ============================================================================

// File: app/api/analytics/dashboard/route.ts
/*
import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  try {
    const { data, error } = await supabase.rpc('get_analytics_dashboard');
    
    if (error) throw error;
    
    return NextResponse.json(data);
  } catch (error) {
    console.error('Analytics API error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch analytics' },
      { status: 500 }
    );
  }
}
*/

// ============================================================================
// Server Component Example (Next.js)
// ============================================================================

// File: app/admin/analytics/page.tsx
/*
import { createClient } from '@supabase/supabase-js';

export default async function AnalyticsPage() {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  const { data: dashboard } = await supabase.rpc('get_analytics_dashboard');

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">Analytics Dashboard</h1>
      <pre>{JSON.stringify(dashboard, null, 2)}</pre>
    </div>
  );
}
*/
