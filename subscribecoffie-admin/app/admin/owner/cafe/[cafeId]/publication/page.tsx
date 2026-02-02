import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';
import { redirect } from 'next/navigation';
import { OwnerSidebar } from '@/components/OwnerSidebar';
import { CafeSwitcher } from '@/components/CafeSwitcher';
import { Breadcrumbs } from '@/components/Breadcrumbs';
import { CafeStatusBadge } from '@/components/CafeStatusBadge';
import Link from 'next/link';

export default async function CafePublicationPage({
  params,
}: {
  params: Promise<{ cafeId: string }>;
}) {
  const { userId } = await getUserRole();
  const { cafeId } = await params;

  if (!userId) {
    redirect('/login');
  }

  const supabase = await createServerClient();
  const { data: cafes } = await supabase.rpc('get_owner_cafes');

  const ownsCafe = cafes?.some((cafe: any) => cafe.id === cafeId);
  if (!ownsCafe) {
    redirect('/admin/owner/dashboard');
  }

  const { data: cafe } = await supabase
    .from('cafes')
    .select('*')
    .eq('id', cafeId)
    .single();

  // Get menu items count
  const { data: menuItems } = await supabase
    .from('menu_items')
    .select('id')
    .eq('cafe_id', cafeId);

  const menuItemsCount = menuItems?.length || 0;

  // Check requirements
  const hasBasicInfo = !!(cafe?.name && cafe?.address && cafe?.phone && cafe?.email);
  const hasWorkingHours = !!(cafe?.opening_time && cafe?.closing_time);
  const hasMenu = menuItemsCount > 0;
  const hasDescription = !!cafe?.description;
  
  const checklistItems = [
    {
      id: 'basic_info',
      title: 'Основная информация',
      description: 'Название, адрес, телефон, email',
      completed: hasBasicInfo,
      link: `/admin/owner/cafes/${cafeId}`,
    },
    {
      id: 'working_hours',
      title: 'Часы работы',
      description: 'Время открытия и закрытия',
      completed: hasWorkingHours,
      link: `/admin/owner/cafe/${cafeId}/settings`,
    },
    {
      id: 'menu',
      title: 'Меню',
      description: `Добавлено позиций: ${menuItemsCount}`,
      completed: hasMenu,
      link: `/admin/owner/cafe/${cafeId}/menu`,
    },
    {
      id: 'description',
      title: 'Описание кофейни',
      description: 'Расскажите о вашей кофейне',
      completed: hasDescription,
      link: `/admin/owner/cafe/${cafeId}/storefront`,
    },
  ];

  const completedCount = checklistItems.filter((item) => item.completed).length;
  const totalCount = checklistItems.length;
  const progress = (completedCount / totalCount) * 100;
  const allCompleted = completedCount === totalCount;

  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="cafe" cafeId={cafeId} />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-4xl">
          {/* Breadcrumbs */}
          <Breadcrumbs
            items={[
              { label: 'Главная', href: '/admin/owner/dashboard' },
              { label: 'Мои кофейни', href: '/admin/owner/cafes' },
              {
                label: cafe?.name || 'Кофейня',
                href: `/admin/owner/cafe/${cafeId}/dashboard`,
              },
              { label: 'Публикация' },
            ]}
          />

          {/* Header */}
          <div className="mb-6 flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-zinc-900">
                Публикация кофейни
              </h1>
              <p className="mt-1 text-sm text-zinc-600">{cafe?.name}</p>
            </div>
            <CafeSwitcher currentCafeId={cafeId} cafes={cafes || []} />
          </div>

          {/* Current Status */}
          <div className="mb-6 rounded-lg border border-zinc-200 bg-white p-6">
            <div className="flex items-start justify-between">
              <div>
                <h2 className="mb-2 text-lg font-semibold text-zinc-900">
                  Текущий статус
                </h2>
                <p className="mb-4 text-sm text-zinc-600">
                  Измените статус публикации вашей кофейни
                </p>
              </div>
              <CafeStatusBadge
                cafeId={cafeId}
                currentStatus={cafe?.status || 'draft'}
              />
            </div>

            {/* Status descriptions */}
            <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-2">
              <div className="rounded-lg bg-blue-50 p-3">
                <p className="text-sm font-medium text-blue-900">
                  📝 Черновик
                </p>
                <p className="mt-1 text-xs text-blue-700">
                  Кофейня не видна пользователям
                </p>
              </div>
              <div className="rounded-lg bg-yellow-50 p-3">
                <p className="text-sm font-medium text-yellow-900">
                  ⏳ На модерации
                </p>
                <p className="mt-1 text-xs text-yellow-700">
                  Отправлено на проверку администратору
                </p>
              </div>
              <div className="rounded-lg bg-green-50 p-3">
                <p className="text-sm font-medium text-green-900">
                  ✅ Опубликовано
                </p>
                <p className="mt-1 text-xs text-green-700">
                  Кофейня видна всем пользователям
                </p>
              </div>
              <div className="rounded-lg bg-gray-50 p-3">
                <p className="text-sm font-medium text-gray-900">
                  ⏸️ Приостановлено
                </p>
                <p className="mt-1 text-xs text-gray-700">
                  Временно скрыта от пользователей
                </p>
              </div>
            </div>
          </div>

          {/* Progress Bar */}
          <div className="mb-6 rounded-lg border border-zinc-200 bg-white p-6">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-zinc-900">
                Готовность к публикации
              </h2>
              <span className="text-sm font-medium text-zinc-600">
                {completedCount} / {totalCount}
              </span>
            </div>
            <div className="mb-2 h-3 w-full rounded-full bg-zinc-200">
              <div
                className="h-3 rounded-full bg-green-600 transition-all duration-500"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="text-xs text-zinc-500">
              {allCompleted
                ? '✅ Все требования выполнены! Можно публиковать'
                : `Выполните все пункты чтобы опубликовать кофейню`}
            </p>
          </div>

          {/* Checklist */}
          <div className="rounded-lg border border-zinc-200 bg-white p-6">
            <h2 className="mb-4 text-lg font-semibold text-zinc-900">
              Чек-лист публикации
            </h2>
            <div className="space-y-3">
              {checklistItems.map((item) => (
                <div
                  key={item.id}
                  className="flex items-start gap-4 rounded-lg border border-zinc-200 p-4 transition-colors hover:bg-zinc-50"
                >
                  <div
                    className={`mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full ${
                      item.completed
                        ? 'bg-green-100 text-green-600'
                        : 'bg-zinc-100 text-zinc-400'
                    }`}
                  >
                    {item.completed ? '✓' : '○'}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-medium text-zinc-900">{item.title}</h3>
                    <p className="mt-0.5 text-sm text-zinc-600">
                      {item.description}
                    </p>
                  </div>
                  {!item.completed && (
                    <Link
                      href={item.link}
                      className="shrink-0 rounded-lg border border-zinc-200 px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-100"
                    >
                      Настроить →
                    </Link>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Publication Tips */}
          <div className="mt-6 rounded-lg border border-blue-200 bg-blue-50 p-6">
            <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold text-blue-900">
              <span>💡</span>
              <span>Советы по публикации</span>
            </h3>
            <ul className="space-y-2 text-sm text-blue-800">
              <li>• Заполните все обязательные поля для успешной публикации</li>
              <li>
                • Добавьте качественные фотографии в разделе "Витрина" для
                большей привлекательности
              </li>
              <li>
                • Убедитесь что меню актуально и цены указаны корректно
              </li>
              <li>
                • После публикации кофейня станет видна всем пользователям
                приложения
              </li>
            </ul>
          </div>
        </div>
      </main>
    </div>
  );
}
