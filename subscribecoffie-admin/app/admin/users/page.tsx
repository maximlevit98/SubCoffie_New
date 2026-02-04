import Link from "next/link";
import { listUsers, getUsersStats } from "../../../lib/supabase/queries/users";

type UsersPageProps = {
  searchParams?: {
    search?: string;
    role?: string;
    page?: string;
  };
};

export default async function UsersPage({ searchParams }: UsersPageProps) {
  const search = searchParams?.search || "";
  const role = searchParams?.role || "";
  const page = parseInt(searchParams?.page || "1", 10);
  const limit = 50;
  const offset = (page - 1) * limit;

  let users: any[] = [];
  let stats: any = null;
  let total = 0;
  let error: string | null = null;

  try {
    const [usersResult, statsResult] = await Promise.all([
      listUsers({ search, role: role || undefined, limit, offset }),
      getUsersStats(),
    ]);
    users = usersResult.users;
    total = usersResult.total;
    stats = statsResult;
  } catch (e: any) {
    error = e.message;
  }

  if (error) {
    return (
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-semibold">Пользователи</h2>
          <span className="text-sm text-red-600">Supabase: FAIL</span>
        </div>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить пользователей: {error}
        </p>
      </section>
    );
  }

  const totalPages = Math.ceil(total / limit);

  return (
    <section className="space-y-6">
      {/* Header with Stats */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-semibold">Пользователи</h2>
          <span className="text-sm text-emerald-600">Supabase: OK</span>
        </div>

        {/* Quick Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Всего пользователей</p>
              <p className="text-2xl font-semibold mt-1">
                {stats.totalUsers}
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Новых за 30 дней</p>
              <p className="text-2xl font-semibold mt-1">
                {stats.newUsers}
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Владельцев кофеен</p>
              <p className="text-2xl font-semibold mt-1">
                {stats.roleStats.owner || 0}
              </p>
            </div>
            <div className="rounded-lg border border-zinc-200 bg-white p-4">
              <p className="text-sm text-zinc-500">Администраторов</p>
              <p className="text-2xl font-semibold mt-1">
                {stats.roleStats.admin || 0}
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="flex gap-4">
        <div className="flex-1">
          <form action="/admin/users" method="get">
            <input
              type="text"
              name="search"
              placeholder="Поиск по имени, email или телефону..."
              defaultValue={search}
              className="w-full px-4 py-2 border border-zinc-300 rounded-lg"
            />
            {role && <input type="hidden" name="role" value={role} />}
          </form>
        </div>
        <div className="flex gap-2">
          <Link
            href="/admin/users"
            className={`px-4 py-2 rounded-lg text-sm ${
              !role
                ? "bg-zinc-900 text-white"
                : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
            }`}
          >
            Все
          </Link>
          {["user", "owner", "admin"].map((r) => (
            <Link
              key={r}
              href={`/admin/users?role=${r}`}
              className={`px-4 py-2 rounded-lg text-sm ${
                role === r
                  ? "bg-zinc-900 text-white"
                  : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              }`}
            >
              {r === "user" ? "Клиенты" : r === "owner" ? "Владельцы" : "Админы"}
            </Link>
          ))}
        </div>
      </div>

      {/* Users Table */}
      <div className="overflow-x-auto rounded-lg border border-zinc-200 bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-zinc-600">
            <tr>
              <th className="px-4 py-3 font-medium">Имя</th>
              <th className="px-4 py-3 font-medium">Email</th>
              <th className="px-4 py-3 font-medium">Телефон</th>
              <th className="px-4 py-3 font-medium">Роль</th>
              <th className="px-4 py-3 font-medium">Провайдер</th>
              <th className="px-4 py-3 font-medium">Регистрация</th>
              <th className="px-4 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {users.length === 0 ? (
              <tr>
                <td className="px-4 py-8 text-center text-zinc-500" colSpan={7}>
                  Пользователи не найдены
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id} className="text-zinc-700 hover:bg-zinc-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      {user.avatar_url ? (
                        <img
                          src={user.avatar_url}
                          alt={user.full_name || "User"}
                          className="w-8 h-8 rounded-full"
                        />
                      ) : (
                        <div className="w-8 h-8 rounded-full bg-zinc-200 flex items-center justify-center">
                          <span className="text-xs font-semibold">
                            {(user.full_name || "?").charAt(0).toUpperCase()}
                          </span>
                        </div>
                      )}
                      <span className="font-medium">
                        {user.full_name || "—"}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-xs">{user.email || "—"}</td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {user.phone || "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
                        user.role === "admin"
                          ? "bg-red-100 text-red-700"
                          : user.role === "owner"
                          ? "bg-blue-100 text-blue-700"
                          : "bg-zinc-100 text-zinc-700"
                      }`}
                    >
                      {user.role}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center gap-1 text-xs text-zinc-500">
                      {user.auth_provider === "google" && "🔵 Google"}
                      {user.auth_provider === "apple" && "🍎 Apple"}
                      {user.auth_provider === "email" && "📧 Email"}
                      {user.auth_provider === "phone" && "📱 Phone"}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {new Date(user.created_at).toLocaleDateString("ru-RU")}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/admin/users/${user.id}`}
                      className="inline-flex items-center rounded border border-zinc-300 px-3 py-1 text-xs font-medium hover:bg-zinc-50"
                    >
                      Подробнее →
                    </Link>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-zinc-600">
            Показано {offset + 1}-{Math.min(offset + limit, total)} из {total}
          </p>
          <div className="flex gap-2">
            {page > 1 && (
              <Link
                href={`/admin/users?page=${page - 1}${search ? `&search=${search}` : ""}${role ? `&role=${role}` : ""}`}
                className="px-3 py-1 border border-zinc-300 rounded hover:bg-zinc-50 text-sm"
              >
                ← Назад
              </Link>
            )}
            {page < totalPages && (
              <Link
                href={`/admin/users?page=${page + 1}${search ? `&search=${search}` : ""}${role ? `&role=${role}` : ""}`}
                className="px-3 py-1 border border-zinc-300 rounded hover:bg-zinc-50 text-sm"
              >
                Вперёд →
              </Link>
            )}
          </div>
        </div>
      )}
    </section>
  );
}
