'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

// Types
type DaySchedule = {
  isOpen: boolean;
  openTime: string;
  closeTime: string;
};

type WorkingHours = {
  monday: DaySchedule;
  tuesday: DaySchedule;
  wednesday: DaySchedule;
  thursday: DaySchedule;
  friday: DaySchedule;
  saturday: DaySchedule;
  sunday: DaySchedule;
};

type CafeFormData = {
  // Step 1: Basic Info
  name: string;
  address: string;
  phone: string;
  email: string;
  city: string;
  // Step 2: Working Hours
  workingHours: WorkingHours;
  // Step 3: Pre-order Slots
  preorderInterval: number; // minutes
  slotsPerInterval: number;
  preorderStartHour: number;
  // Step 4: Storefront
  description: string;
  logoUrl: string;
  coverUrl: string;
};

const defaultSchedule: DaySchedule = {
  isOpen: true,
  openTime: '09:00',
  closeTime: '18:00',
};

const initialFormData: CafeFormData = {
  name: '',
  address: '',
  phone: '',
  email: '',
  city: 'Москва',
  workingHours: {
    monday: { ...defaultSchedule },
    tuesday: { ...defaultSchedule },
    wednesday: { ...defaultSchedule },
    thursday: { ...defaultSchedule },
    friday: { ...defaultSchedule },
    saturday: { ...defaultSchedule },
    sunday: { isOpen: false, openTime: '09:00', closeTime: '18:00' },
  },
  preorderInterval: 30,
  slotsPerInterval: 10,
  preorderStartHour: 1,
  description: '',
  logoUrl: '',
  coverUrl: '',
};

export function CafeCreationForm() {
  const router = useRouter();
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState<CafeFormData>(initialFormData);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const totalSteps = 4;

  const updateFormData = (updates: Partial<CafeFormData>) => {
    setFormData((prev) => ({ ...prev, ...updates }));
  };

  const validateStep = (step: number): string | null => {
    switch (step) {
      case 1:
        if (!formData.name.trim()) return 'Введите название кофейни';
        if (!formData.address.trim()) return 'Введите адрес';
        if (!formData.phone.trim()) return 'Введите телефон';
        if (!formData.email.trim()) return 'Введите email';
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
          return 'Введите корректный email';
        }
        return null;
      case 2:
        // Check if at least one day is open
        const hasOpenDay = Object.values(formData.workingHours).some(
          (day) => day.isOpen
        );
        if (!hasOpenDay) return 'Выберите хотя бы один рабочий день';
        return null;
      case 3:
        if (formData.preorderInterval < 15)
          return 'Минимальный интервал - 15 минут';
        if (formData.slotsPerInterval < 1) return 'Минимум 1 слот';
        return null;
      case 4:
        // Optional step, no validation
        return null;
      default:
        return null;
    }
  };

  const handleNext = () => {
    const validationError = validateStep(currentStep);
    if (validationError) {
      setError(validationError);
      return;
    }
    setError(null);
    setCurrentStep((prev) => Math.min(prev + 1, totalSteps));
  };

  const handleBack = () => {
    setError(null);
    setCurrentStep((prev) => Math.max(prev - 1, 1));
  };

  const handleSubmit = async () => {
    const validationError = validateStep(currentStep);
    if (validationError) {
      setError(validationError);
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const response = await fetch('/api/owner/cafes/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Не удалось создать кофейню');
      }

      // Redirect to cafe dashboard
      router.push(`/admin/owner/cafe/${result.cafeId}/dashboard`);
    } catch (err) {
      console.error('Cafe creation error:', err);
      setError(
        err instanceof Error ? err.message : 'Не удалось создать кофейню'
      );
      setIsSubmitting(false);
    }
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 1:
        return <Step1BasicInfo formData={formData} updateFormData={updateFormData} />;
      case 2:
        return (
          <Step2WorkingHours formData={formData} updateFormData={updateFormData} />
        );
      case 3:
        return <Step3PreorderSlots formData={formData} updateFormData={updateFormData} />;
      case 4:
        return <Step4Storefront formData={formData} updateFormData={updateFormData} />;
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      {/* Progress Bar */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-sm">
          <span className="font-medium text-zinc-700">
            Шаг {currentStep} из {totalSteps}
          </span>
          <span className="text-zinc-500">
            {Math.round((currentStep / totalSteps) * 100)}%
          </span>
        </div>
        <div className="h-2 rounded-full bg-zinc-200">
          <div
            className="h-full rounded-full bg-blue-600 transition-all duration-300"
            style={{ width: `${(currentStep / totalSteps) * 100}%` }}
          />
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Step Content */}
      <div className="rounded-lg border border-zinc-200 bg-white p-6">
        {renderStepContent()}
      </div>

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={handleBack}
          disabled={currentStep === 1 || isSubmitting}
          className="rounded-lg border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
        >
          ← Назад
        </button>

        {currentStep < totalSteps ? (
          <button
            type="button"
            onClick={handleNext}
            disabled={isSubmitting}
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Далее →
          </button>
        ) : (
          <button
            type="button"
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isSubmitting ? 'Создаём...' : '✓ Создать кофейню'}
          </button>
        )}
      </div>
    </div>
  );
}

// Step Components
function Step1BasicInfo({
  formData,
  updateFormData,
}: {
  formData: CafeFormData;
  updateFormData: (updates: Partial<CafeFormData>) => void;
}) {
  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-zinc-900">
        Основная информация
      </h3>
      <p className="text-sm text-zinc-600">
        Расскажите базовую информацию о вашей кофейне
      </p>

      <div className="space-y-4">
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Название кофейни <span className="text-red-500">*</span>
          </span>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => updateFormData({ name: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="Например: Coffee Point"
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Адрес <span className="text-red-500">*</span>
          </span>
          <input
            type="text"
            value={formData.address}
            onChange={(e) => updateFormData({ address: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="Например: ул. Ленина, 10"
          />
        </label>

        <div className="grid grid-cols-2 gap-4">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Телефон <span className="text-red-500">*</span>
            </span>
            <input
              type="tel"
              value={formData.phone}
              onChange={(e) => updateFormData({ phone: e.target.value })}
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="+7 (999) 123-45-67"
            />
          </label>

          <label className="block">
            <span className="mb-1 block text-sm font-medium text-zinc-700">
              Email <span className="text-red-500">*</span>
            </span>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => updateFormData({ email: e.target.value })}
              className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="cafe@example.com"
            />
          </label>
        </div>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Город
          </span>
          <input
            type="text"
            value={formData.city}
            onChange={(e) => updateFormData({ city: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="Москва"
          />
        </label>
      </div>
    </div>
  );
}

function Step2WorkingHours({
  formData,
  updateFormData,
}: {
  formData: CafeFormData;
  updateFormData: (updates: Partial<CafeFormData>) => void;
}) {
  const days: Array<keyof WorkingHours> = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  const dayLabels = {
    monday: 'Понедельник',
    tuesday: 'Вторник',
    wednesday: 'Среда',
    thursday: 'Четверг',
    friday: 'Пятница',
    saturday: 'Суббота',
    sunday: 'Воскресенье',
  };

  const updateDaySchedule = (
    day: keyof WorkingHours,
    updates: Partial<DaySchedule>
  ) => {
    updateFormData({
      workingHours: {
        ...formData.workingHours,
        [day]: { ...formData.workingHours[day], ...updates },
      },
    });
  };

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-zinc-900">График работы</h3>
      <p className="text-sm text-zinc-600">
        Укажите часы работы для каждого дня недели
      </p>

      <div className="space-y-3">
        {days.map((day) => {
          const schedule = formData.workingHours[day];
          return (
            <div
              key={day}
              className="flex items-center gap-4 rounded-lg border border-zinc-200 p-4"
            >
              <label className="flex min-w-[140px] items-center gap-2">
                <input
                  type="checkbox"
                  checked={schedule.isOpen}
                  onChange={(e) =>
                    updateDaySchedule(day, { isOpen: e.target.checked })
                  }
                  className="h-4 w-4 rounded border-zinc-300 text-blue-600 focus:ring-blue-500"
                />
                <span className="text-sm font-medium text-zinc-700">
                  {dayLabels[day]}
                </span>
              </label>

              {schedule.isOpen && (
                <div className="flex items-center gap-2">
                  <input
                    type="time"
                    value={schedule.openTime}
                    onChange={(e) =>
                      updateDaySchedule(day, { openTime: e.target.value })
                    }
                    className="rounded border border-zinc-300 px-2 py-1 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                  <span className="text-sm text-zinc-500">—</span>
                  <input
                    type="time"
                    value={schedule.closeTime}
                    onChange={(e) =>
                      updateDaySchedule(day, { closeTime: e.target.value })
                    }
                    className="rounded border border-zinc-300 px-2 py-1 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
              )}

              {!schedule.isOpen && (
                <span className="text-sm text-zinc-400">Выходной</span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function Step3PreorderSlots({
  formData,
  updateFormData,
}: {
  formData: CafeFormData;
  updateFormData: (updates: Partial<CafeFormData>) => void;
}) {
  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-zinc-900">Слоты предзаказа</h3>
      <p className="text-sm text-zinc-600">
        Настройте систему предзаказов для вашей кофейни
      </p>

      <div className="space-y-4">
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Интервал слотов (минуты)
          </span>
          <input
            type="number"
            min="15"
            step="15"
            value={formData.preorderInterval}
            onChange={(e) =>
              updateFormData({ preorderInterval: parseInt(e.target.value) || 30 })
            }
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
          <p className="mt-1 text-xs text-zinc-500">
            Например: 30 минут = слоты каждые полчаса (09:00, 09:30, 10:00...)
          </p>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Количество заказов на слот
          </span>
          <input
            type="number"
            min="1"
            value={formData.slotsPerInterval}
            onChange={(e) =>
              updateFormData({ slotsPerInterval: parseInt(e.target.value) || 10 })
            }
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
          <p className="mt-1 text-xs text-zinc-500">
            Максимальное количество заказов, которые можно принять в один слот
          </p>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Начало приёма предзаказов (часов до слота)
          </span>
          <input
            type="number"
            min="1"
            max="24"
            value={formData.preorderStartHour}
            onChange={(e) =>
              updateFormData({
                preorderStartHour: parseInt(e.target.value) || 1,
              })
            }
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
          <p className="mt-1 text-xs text-zinc-500">
            За сколько часов до слота открывать возможность предзаказа
          </p>
        </label>
      </div>
    </div>
  );
}

function Step4Storefront({
  formData,
  updateFormData,
}: {
  formData: CafeFormData;
  updateFormData: (updates: Partial<CafeFormData>) => void;
}) {
  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-zinc-900">
        Витрина (опционально)
      </h3>
      <p className="text-sm text-zinc-600">
        Добавьте описание и изображения для витрины вашей кофейни
      </p>

      <div className="space-y-4">
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            Описание кофейни
          </span>
          <textarea
            value={formData.description}
            onChange={(e) => updateFormData({ description: e.target.value })}
            rows={4}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="Расскажите о вашей кофейне..."
          />
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            URL логотипа
          </span>
          <input
            type="url"
            value={formData.logoUrl}
            onChange={(e) => updateFormData({ logoUrl: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="https://example.com/logo.png"
          />
          <p className="mt-1 text-xs text-zinc-500">
            Добавите позже через загрузку файлов
          </p>
        </label>

        <label className="block">
          <span className="mb-1 block text-sm font-medium text-zinc-700">
            URL обложки
          </span>
          <input
            type="url"
            value={formData.coverUrl}
            onChange={(e) => updateFormData({ coverUrl: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            placeholder="https://example.com/cover.jpg"
          />
          <p className="mt-1 text-xs text-zinc-500">
            Добавите позже через загрузку файлов
          </p>
        </label>
      </div>

      <div className="rounded-lg bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          💡 <strong>Совет:</strong> После создания кофейни вы сможете загрузить
          изображения, добавить меню и настроить витрину в разделе "Витрина"
        </p>
      </div>
    </div>
  );
}
