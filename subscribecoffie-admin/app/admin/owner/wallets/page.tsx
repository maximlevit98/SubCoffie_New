export default async function OwnerWalletsPage() {
  return (
    <section className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold">💰 Кошельки кафе</h2>
          <p className="mt-1 text-sm text-zinc-600">
            Управление кошельками клиентов ваших кофеен
          </p>
        </div>
      </div>

      <div className="rounded-lg border border-zinc-200 bg-white p-8 text-center">
        <p className="text-zinc-600">
          Функционал управления кошельками будет добавлен позже
        </p>
        <p className="mt-2 text-sm text-zinc-500">
          Здесь вы сможете просматривать статистику по кошелькам клиентов,
          привязанным к вашим кофейням (Cafe Wallet)
        </p>
        
        <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-zinc-200 p-4">
            <p className="text-2xl font-bold text-zinc-900">—</p>
            <p className="text-sm text-zinc-600">Активных кошельков</p>
          </div>
          <div className="rounded-lg border border-zinc-200 p-4">
            <p className="text-2xl font-bold text-zinc-900">—</p>
            <p className="text-sm text-zinc-600">Общий баланс</p>
          </div>
          <div className="rounded-lg border border-zinc-200 p-4">
            <p className="text-2xl font-bold text-zinc-900">—</p>
            <p className="text-sm text-zinc-600">Транзакций за месяц</p>
          </div>
        </div>
      </div>
    </section>
  );
}
