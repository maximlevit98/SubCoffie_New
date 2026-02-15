"use client";

import { useState } from "react";
import Link from "next/link";
import { 
  type AdminWalletOverview,
  type AdminWalletTransaction,
  type AdminWalletPayment,
  type AdminWalletOrder,
} from "../../../../lib/supabase/queries/wallets";
import { OverviewTab } from "./OverviewTab";
import { TransactionsTab } from "./TransactionsTab";
import { PaymentsTab } from "./PaymentsTab";
import { OrdersTab } from "./OrdersTab";

type Tab = "overview" | "transactions" | "payments" | "orders";

type WalletDetailClientProps = {
  overview: AdminWalletOverview;
  transactions: AdminWalletTransaction[];
  payments: AdminWalletPayment[];
  orders: AdminWalletOrder[];
};

export function WalletDetailClient({
  overview,
  transactions,
  payments,
  orders,
}: WalletDetailClientProps) {
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [transactionsPage, setTransactionsPage] = useState(1);
  const [paymentsPage, setPaymentsPage] = useState(1);
  const [ordersPage, setOrdersPage] = useState(1);
  const pageSize = 50;

  const tabs: Array<{ id: Tab; label: string; count?: number; icon: string }> = [
    { id: "overview", label: "Обзор", icon: "📊" },
    { id: "transactions", label: "Транзакции", count: overview.total_transactions, icon: "💳" },
    { id: "payments", label: "Платежи", count: overview.total_payments, icon: "💰" },
    { id: "orders", label: "Заказы", count: overview.total_orders, icon: "🛒" },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <h2 className="text-2xl font-semibold">Кошелёк пользователя</h2>
            <WalletTypeBadge type={overview.wallet_type} />
          </div>
          <div className="flex items-center gap-4 text-sm text-zinc-500">
            <span>👤 {overview.user_full_name || "Имя не указано"}</span>
            {overview.user_email && <span>✉️ {overview.user_email}</span>}
            {overview.user_phone && <span className="font-mono">📱 {overview.user_phone}</span>}
          </div>
        </div>
        
        <div className="flex items-center gap-3">
          <Link
            href={`/admin/users`}
            className="px-4 py-2 text-sm text-zinc-600 hover:text-zinc-900 border border-zinc-300 rounded-md hover:bg-zinc-50"
          >
            Профиль пользователя
          </Link>
          <Link
            href="/admin/wallets"
            className="px-4 py-2 text-sm text-zinc-600 hover:text-zinc-900 border border-zinc-300 rounded-md hover:bg-zinc-50"
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
              className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.id
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-zinc-600 hover:text-zinc-900 hover:border-zinc-300"
              }`}
            >
              <span className="flex items-center gap-2">
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
                {tab.count !== undefined && (
                  <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                    activeTab === tab.id
                      ? "bg-blue-100 text-blue-700"
                      : "bg-zinc-100 text-zinc-600"
                  }`}>
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
        {activeTab === "overview" && (
          <OverviewTab overview={overview} />
        )}
        
        {activeTab === "transactions" && (
          <TransactionsTab
            transactions={transactions}
            currentPage={transactionsPage}
            hasMore={transactions.length === pageSize}
            onPageChange={(page) => {
              setTransactionsPage(page);
              // TODO: Fetch new data when pagination is implemented server-side
            }}
          />
        )}
        
        {activeTab === "payments" && (
          <PaymentsTab
            payments={payments}
            currentPage={paymentsPage}
            hasMore={payments.length === pageSize}
            onPageChange={(page) => {
              setPaymentsPage(page);
              // TODO: Fetch new data when pagination is implemented server-side
            }}
          />
        )}
        
        {activeTab === "orders" && (
          <OrdersTab
            orders={orders}
            currentPage={ordersPage}
            hasMore={orders.length === pageSize}
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

function WalletTypeBadge({ type }: { type: string }) {
  const isCityPass = type === "citypass";
  return (
    <span
      className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${
        isCityPass
          ? "bg-blue-100 text-blue-700"
          : "bg-green-100 text-green-700"
      }`}
    >
      {isCityPass ? "CityPass" : "Cafe Wallet"}
    </span>
  );
}
