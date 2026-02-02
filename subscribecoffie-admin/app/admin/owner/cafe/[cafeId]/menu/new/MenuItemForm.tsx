'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

type SizeOption = {
  size: string;
  price_credits: number;
};

type MenuItemFormData = {
  name: string;
  description: string;
  category: string;
  price_credits: number;
  prep_time_sec: number;
  is_available: boolean;
  sort_order: number;
  ingredients: string;
  sizes: SizeOption[];
};

type MenuItemFormProps = {
  cafeId: string;
  defaultCategory?: string;
  initialData?: MenuItemFormData & { id: string };
};

const categories = [
  { value: 'drinks', label: 'Напитки' },
  { value: 'food', label: 'Еда' },
  { value: 'syrups', label: 'Сиропы' },
  { value: 'merch', label: 'Мерч' },
];

export function MenuItemForm({
  cafeId,
  defaultCategory,
  initialData,
}: MenuItemFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [formData, setFormData] = useState<MenuItemFormData>({
    name: initialData?.name || '',
    description: initialData?.description || '',
    category: initialData?.category || defaultCategory || 'drinks',
    price_credits: initialData?.price_credits || 100,
    prep_time_sec: initialData?.prep_time_sec || 300,
    is_available: initialData?.is_available ?? true,
    sort_order: initialData?.sort_order || 0,
    ingredients: initialData?.ingredients || '',
    sizes: initialData?.sizes || [],
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // Validation
    if (!formData.name.trim()) {
      setError('Введите название');
      return;
    }
    if (!formData.description.trim()) {
      setError('Введите описание');
      return;
    }
    if (formData.price_credits < 1) {
      setError('Цена должна быть больше 0');
      return;
    }

    setIsSubmitting(true);

    try {
      const url = initialData
        ? `/api/owner/menu-items/${initialData.id}`
        : '/api/owner/menu-items';

      const method = initialData ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...formData,
          cafe_id: cafeId,
          title: formData.name, // Sync title with name
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Не удалось сохранить позицию');
      }

      // Redirect back to menu
      router.push(`/admin/owner/cafe/${cafeId}/menu`);
    } catch (err) {
      console.error('Form submission error:', err);
      setError(
        err instanceof Error ? err.message : 'Не удалось сохранить позицию'
      );
      setIsSubmitting(false);
    }
  };

  const addSize = () => {
    setFormData({
      ...formData,
      sizes: [...formData.sizes, { size: '', price_credits: 100 }],
    });
  };

  const updateSize = (index: number, field: 'size' | 'price_credits', value: string | number) => {
    const newSizes = [...formData.sizes];
    newSizes[index] = {
      ...newSizes[index],
      [field]: value,
    };
    setFormData({ ...formData, sizes: newSizes });
  };

  const removeSize = (index: number) => {
    setFormData({
      ...formData,
      sizes: formData.sizes.filter((_, i) => i !== index),
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        <div className="space-y-4">
          {/* Name */}
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Название <span className="text-red-500">*</span>
            </span>
            <input
              type="text"
              value={formData.name}
              onChange={(e) =>
                setFormData({ ...formData, name: e.target.value })
              }
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="Например: Капучино"
              disabled={isSubmitting}
            />
          </label>

          {/* Description */}
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Описание <span className="text-red-500">*</span>
            </span>
            <textarea
              value={formData.description}
              onChange={(e) =>
                setFormData({ ...formData, description: e.target.value })
              }
              rows={3}
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="Расскажите о позиции..."
              disabled={isSubmitting}
            />
          </label>

          {/* Ingredients */}
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Состав
            </span>
            <textarea
              value={formData.ingredients}
              onChange={(e) =>
                setFormData({ ...formData, ingredients: e.target.value })
              }
              rows={2}
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="Например: Эспрессо, молоко, сироп"
              disabled={isSubmitting}
            />
            <p className="mt-1 text-xs text-zinc-500">
              Перечислите ингредиенты через запятую
            </p>
          </label>

          {/* Category */}
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Категория <span className="text-red-500">*</span>
            </span>
            <select
              value={formData.category}
              onChange={(e) =>
                setFormData({ ...formData, category: e.target.value })
              }
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              disabled={isSubmitting}
            >
              {categories.map((cat) => (
                <option key={cat.value} value={cat.value}>
                  {cat.label}
                </option>
              ))}
            </select>
          </label>

          <div className="grid grid-cols-2 gap-4">
            {/* Price */}
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-zinc-700">
                Цена (кредиты) <span className="text-red-500">*</span>
              </span>
              <input
                type="number"
                min="1"
                value={formData.price_credits}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    price_credits: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                disabled={isSubmitting}
              />
            </label>

            {/* Prep Time */}
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-zinc-700">
                Время приготовления (минуты)
              </span>
              <input
                type="number"
                min="0"
                value={Math.round(formData.prep_time_sec / 60)}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    prep_time_sec: (parseInt(e.target.value) || 0) * 60,
                  })
                }
                className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                disabled={isSubmitting}
              />
            </label>
          </div>

          {/* Sizes/Volumes */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="block text-sm font-medium text-zinc-700">
                Размеры и цены (литраж)
              </label>
              <button
                type="button"
                onClick={addSize}
                disabled={isSubmitting}
                className="text-sm text-blue-600 hover:text-blue-700 disabled:opacity-50"
              >
                + Добавить размер
              </button>
            </div>
            
            {formData.sizes.length > 0 ? (
              <div className="space-y-2">
                {formData.sizes.map((sizeOption, index) => (
                  <div key={index} className="flex items-center gap-2">
                    <input
                      type="text"
                      value={sizeOption.size}
                      onChange={(e) => updateSize(index, 'size', e.target.value)}
                      placeholder="0.3л"
                      className="flex-1 rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                      disabled={isSubmitting}
                    />
                    <input
                      type="number"
                      min="1"
                      value={sizeOption.price_credits}
                      onChange={(e) => updateSize(index, 'price_credits', parseInt(e.target.value) || 0)}
                      placeholder="Цена"
                      className="w-24 rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                      disabled={isSubmitting}
                    />
                    <span className="text-xs text-zinc-500">кр</span>
                    <button
                      type="button"
                      onClick={() => removeSize(index)}
                      disabled={isSubmitting}
                      className="rounded-md p-2 text-red-600 hover:bg-red-50 disabled:opacity-50"
                      title="Удалить"
                    >
                      <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-zinc-500">
                Если позиция доступна в разных объемах (например, 0.3л, 0.5л), добавьте их здесь.
                Иначе используйте базовую цену выше.
              </p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            {/* Sort Order */}
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-zinc-700">
                Порядок сортировки
              </span>
              <input
                type="number"
                min="0"
                value={formData.sort_order}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    sort_order: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                disabled={isSubmitting}
              />
              <p className="mt-1 text-xs text-zinc-500">
                Меньшее число = выше в списке
              </p>
            </label>

            {/* Availability */}
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-zinc-700">
                Статус
              </span>
              <label className="flex items-center gap-2 rounded-lg border border-zinc-300 px-3 py-2 hover:bg-zinc-50">
                <input
                  type="checkbox"
                  checked={formData.is_available}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      is_available: e.target.checked,
                    })
                  }
                  className="h-4 w-4 rounded border-zinc-300 text-blue-600 focus:ring-blue-500"
                  disabled={isSubmitting}
                />
                <span className="text-sm text-zinc-700">
                  Доступно для заказа
                </span>
              </label>
            </label>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={() => router.back()}
          disabled={isSubmitting}
          className="rounded-lg border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
        >
          Отмена
        </button>
        <button
          type="submit"
          disabled={isSubmitting}
          className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {isSubmitting
            ? 'Сохранение...'
            : initialData
            ? 'Сохранить изменения'
            : 'Создать позицию'}
        </button>
      </div>
    </form>
  );
}
