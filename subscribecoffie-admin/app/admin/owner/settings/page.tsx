import { redirect } from 'next/navigation';
import { getUserRole } from '@/lib/supabase/roles';
import { createServerClient } from '@/lib/supabase/server';
import SignOutButton from './SignOutButton';

export default async function OwnerSettingsPage() {
  const { role, userId } = await getUserRole();

  if (!role || !userId || role !== 'owner') {
    redirect('/login');
  }

  // Get owner profile
  const supabase = await createServerClient();
  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, email, phone')
    .eq('id', userId)
    .single();

  // Get owner cafes
  const { data: cafeLinks } = await supabase
    .from('cafe_owners')
    .select('cafe_id, cafes(name)')
    .eq('owner_id', userId);

  return (
    <div className="mx-auto max-w-4xl px-6 py-8">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-zinc-900">⚙️ Настройки профиля</h1>
        <p className="mt-2 text-sm text-zinc-600">
          Управление вашим профилем владельца кофейни
        </p>
      </div>

      {/* Profile Info */}
      <div className="space-y-6">
        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold text-zinc-900">
            👤 Личная информация
          </h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                Email
              </label>
              <p className="mt-1 text-base text-zinc-900">
                {profile?.email || 'Не указан'}
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                Полное имя
              </label>
              <p className="mt-1 text-base text-zinc-900">
                {profile?.full_name || 'Не указано'}
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-zinc-700">
                Телефон
              </label>
              <p className="mt-1 text-base text-zinc-900">
                {profile?.phone || 'Не указан'}
              </p>
            </div>
          </div>
        </div>

        {/* Cafes */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold text-zinc-900">
            ☕ Ваши кофейни
          </h2>
          {cafeLinks && cafeLinks.length > 0 ? (
            <ul className="space-y-2">
              {cafeLinks.map((link: any) => (
                <li
                  key={link.cafe_id}
                  className="flex items-center gap-2 text-sm text-zinc-700"
                >
                  <span className="text-lg">☕</span>
                  <span className="font-medium">
                    {link.cafes?.name || 'Кофейня'}
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-zinc-500">
              У вас пока нет привязанных кофеен.
            </p>
          )}
        </div>

        {/* Role */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold text-zinc-900">
            🔐 Роль и доступ
          </h2>
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <span className="text-sm text-zinc-700">Текущая роль:</span>
              <span className="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-xs font-semibold text-green-800">
                Владелец (Owner)
              </span>
            </div>
            <p className="text-xs text-zinc-500">
              Вы имеете доступ к управлению своими кофейнями через панель владельца.
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold text-zinc-900">
            🚪 Действия
          </h2>
          <div className="space-y-4">
            <div>
              <p className="mb-2 text-sm text-zinc-600">
                Выйти из системы и вернуться на страницу входа
              </p>
              <SignOutButton />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
