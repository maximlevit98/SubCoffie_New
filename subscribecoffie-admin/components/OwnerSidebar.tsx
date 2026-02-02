'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

interface Cafe {
  id: string;
  name: string;
  status: 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';
}

interface OwnerSidebarProps {
  currentContext: 'account' | 'cafe';
  cafeId?: string;
  cafesCount?: number;
  activeOrdersCount?: number;
  unreadNotifications?: number;
}

interface NavItem {
  name: string;
  href: string;
  icon: string;
  badge?: number;
  disabled?: boolean;
}

export function OwnerSidebar({
  currentContext,
  cafeId,
  cafesCount = 0,
  activeOrdersCount = 0,
  unreadNotifications = 0,
}: OwnerSidebarProps) {
  const pathname = usePathname();

  const accountNavigation: NavItem[] = [
    { name: 'Главная', href: '/admin/owner/dashboard', icon: '🏠' },
    {
      name: 'Мои кофейни',
      href: '/admin/owner/cafes',
      icon: '☕',
      badge: cafesCount,
    },
    { name: 'Финансы', href: '/admin/owner/finances', icon: '💰' },
    {
      name: 'Уведомления',
      href: '/admin/owner/notifications',
      icon: '🔔',
      badge: unreadNotifications,
    },
    { name: 'Настройки', href: '/admin/owner/settings', icon: '⚙️' },
  ];

  const cafeNavigation: NavItem[] = cafeId
    ? [
        {
          name: 'Дашборд',
          href: `/admin/owner/cafe/${cafeId}/dashboard`,
          icon: '📊',
        },
        {
          name: 'Заказы',
          href: `/admin/owner/cafe/${cafeId}/orders`,
          icon: '📦',
          badge: activeOrdersCount,
        },
        {
          name: 'Меню',
          href: `/admin/owner/cafe/${cafeId}/menu`,
          icon: '📋',
        },
        {
          name: 'Витрина',
          href: `/admin/owner/cafe/${cafeId}/storefront`,
          icon: '🖼️',
        },
        {
          name: 'Финансы',
          href: `/admin/owner/cafe/${cafeId}/finances`,
          icon: '💵',
        },
        {
          name: 'Настройки',
          href: `/admin/owner/cafe/${cafeId}/settings`,
          icon: '⚙️',
        },
        {
          name: 'Публикация',
          href: `/admin/owner/cafe/${cafeId}/publication`,
          icon: '✅',
        },
      ]
    : [];

  const navigation =
    currentContext === 'account' ? accountNavigation : cafeNavigation;

  const isActive = (href: string) => {
    return pathname === href || pathname.startsWith(href + '/');
  };

  return (
    <aside className="w-64 border-r border-zinc-200 bg-white">
      <nav className="flex flex-col gap-1 p-4">
        {/* Back to Cafes button - показываем только в контексте кофейни */}
        {currentContext === 'cafe' && (
          <>
            <Link
              href="/admin/owner/cafes"
              className="mb-3 flex items-center gap-2 rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
            >
              <span className="text-base">←</span>
              <span>Все кофейни</span>
            </Link>
            <div className="mb-2 border-b border-zinc-200" />
          </>
        )}

        {navigation.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center justify-between rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
              isActive(item.href)
                ? 'bg-blue-50 text-blue-700'
                : item.disabled
                  ? 'cursor-not-allowed text-zinc-400'
                  : 'text-zinc-700 hover:bg-zinc-100'
            }`}
            aria-disabled={item.disabled}
            onClick={(e) => item.disabled && e.preventDefault()}
          >
            <span className="flex items-center gap-2">
              <span className="text-base">{item.icon}</span>
              <span>{item.name}</span>
            </span>
            {item.badge !== undefined && item.badge > 0 && (
              <span className="flex h-5 min-w-[20px] items-center justify-center rounded-full bg-red-500 px-1.5 text-xs font-semibold text-white">
                {item.badge}
              </span>
            )}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
