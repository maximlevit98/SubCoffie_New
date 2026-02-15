"use client";

import { useState } from "react";
import Link from "next/link";
import {
  type AdminWalletOverview,
  type AdminWalletTransaction,
  type AdminWalletPayment,
  type AdminWalletOrder,
} from "@/lib/supabase/queries/wallets";
import { OwnerOverviewTab } from "./OwnerOverviewTab";
import { OwnerTransactionsTab } from "./OwnerTransactionsTab";
import { OwnerPaymentsTab } from "./OwnerPaymentsTab";
import { OwnerOrdersTab } from "./OwnerOrdersTab";

type Tab = "overview" | "transactions" | "payments" | "orders";

type OwnerWalletDetailClientProps = {
  overview: AdminWalletOverview;
  transactions: AdminWalletTransaction[];
  payments: AdminWalletPayment[];
  orders: AdminWalletOrder[];
};

export function OwnerWalletDetailClient({
  overview,
  transactions,
  payments,
  orders,
}: OwnerWalletDetailClientProps) {
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [transactionsPage, setTransactionsPage] = useState(1);
  const [paymentsPage, setPaymentsPage] = useState(1);
  const [ordersPage, setOrdersPage] = useState(1);

  const limit = 50;

  const tabs: Array<{ id: Tab; label: string; count?: number; icon: string }> =
    [
      { id: "overview", label: "Обзор", icon: "📊" },
      {
        id: "transactions",
        label: "Транзакции",
        count: overview.total_transactions,
        icon: "💳",
      },
      {
        id: "payments",
        label: "Платежи",
        count: overview.total_payments,
        icon: "💰",
      },
      {
        id: "orders",
        label: "Заказы",
        count: overview.total_orders,
        icon: "🛒",
      },
    ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <div className="mb-2 flex items-center gap-3">
            <h2 className="text-2xl font-semibold">Кошелёк клиента</h2>
            <WalletTypeBadge type={overview.wallet_type} />
          </div>
          <div className="flex items-center gap-4 text-sm text-zinc-500">
            <span>👤 {overview.user_full_name || "Имя не указано"}</span>
            {overview.user_email && <span>✉️ {overview.user_email}</span>}
            {overview.user_phone && (
              <span className="font-mono">📱 {overview.user_phone}</span>
            )}
          </div>
          {overview.cafe_name && (
            <div className="mt-2 text-sm text-zinc-600">
              <span className="font-medium">Кофейня:</span> {overview.cafe_name}
            </div>
          )}
        </div>

        <div className="flex items-center gap-3">
          <Link
            href="/admin/owner/wallets"
            className="rounded-md border border-zinc-300 px-4 py-2 text-sm text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900"
          >
            ← Все кошельки
          </Link>
        </div>
      </div>

      {/* Tabs Navigation */}
      <div className="border-b border-zinc-200">
        <nav className="flex gap-1">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`border-b-2 px-6 py-3 text-sm font-medium transition-colors ${
                activeTab === tab.id
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-zinc-600 hover:border-zinc-300 hover:text-zinc-900"
              }`}
            >
              <span className="flex items-center gap-2">
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
                {tab.count !== undefined && (
                  <span
                    className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
                      activeTab === tab.id
                        ? "bg-blue-100 text-blue-700"
                        : "bg-zinc-100 text-zinc-600"
                    }`}
                  >
                    {tab.count}
                  </span>
                )}
              </span>
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      <div className="min-h-[400px]">
        {activeTab === "overview" && <OwnerOverviewTab overview={overview} />}

        {activeTab === "transactions" && (
          <OwnerTransactionsTab
            transactions={transactions}
            currentPage={transactionsPage}
            hasMore={transactions.length === limit}
            onPageChange={(page) => {
              setTransactionsPage(page);
              // TODO: Fetch new data when pagination is implemented server-side
            }}
          />
        )}

        {activeTab === "payments" && (
          <OwnerPaymentsTab
            payments={payments}
            currentPage={paymentsPage}
            hasMore={payments.length === limit}
            onPageChange={(page) => {
              setPaymentsPage(page);
              // TODO: Fetch new data when pagination is implemented server-side
            }}
          />
        )}

        {activeTab === "orders" && (
          <OwnerOrdersTab
            orders={orders}
            currentPage={ordersPage}
            hasMore={orders.length === limit}
            onPageChange={(page) => {
              setOrdersPage(page);
              // TODO: Fetch new data when pagination is implemented server-side
            }}
          />
        )}
      </div>
    </div>
  );
}

// Wallet Type Badge Component
function WalletTypeBadge({ type }: { type: string }) {
  const isCityPass = type === "citypass";
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
        isCityPass
          ? "bg-blue-100 text-blue-700"
          : "bg-green-100 text-green-700"
      }`}
    >
      {isCityPass ? "CityPass" : "Cafe Wallet"}
    </span>
  );
}
