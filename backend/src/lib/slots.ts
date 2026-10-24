import type { InspectionSlot } from '@prisma/client';
import { badRequest } from './errors';

/** فترات المعاينة (بتوقيت القاهرة) — نفس الفترات في التطبيق. */
export const SLOTS: Record<InspectionSlot, { startHour: number; endHour: number; label: string }> = {
  MORNING: { startHour: 10, endHour: 12, label: 'صباحاً 10–12' },
  NOON: { startHour: 13, endHour: 15, label: 'ظهراً 1–3' },
  EVENING: { startHour: 17, endHour: 20, label: 'مساءً 5–8' },
};

/** أقصى مدة حجز قدّام (أيام). */
export const MAX_ADVANCE_DAYS = 7;

const TZ = 'Africa/Cairo';

function cairoParts(date: Date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: TZ,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(date);
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  return {
    year: get('year'),
    month: get('month'),
    day: get('day'),
    hour: get('hour'),
    minute: get('minute'),
    second: get('second'),
  };
}

/** تاريخ النهارده في القاهرة بصيغة YYYY-MM-DD */
export function todayCairo(now = new Date()): string {
  const p = cairoParts(now);
  return `${p.year}-${String(p.month).padStart(2, '0')}-${String(p.day).padStart(2, '0')}`;
}

/** الساعة الحالية في القاهرة (بالكسور: 13.5 = 1:30 م) */
export function cairoHour(now = new Date()): number {
  const p = cairoParts(now);
  return p.hour + p.minute / 60;
}

export function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** يحوّل (تاريخ + ساعة بتوقيت القاهرة) لـ Date بالـ UTC (بيراعي التوقيت الصيفي). */
export function cairoLocalToUtc(dateStr: string, hour: number): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hour);
  const p = cairoParts(new Date(guess));
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  const offsetMs = asUtc - guess;
  return new Date(guess - offsetMs);
}

/** بيتأكد إن الموعد مقبول: مش في الماضي، وفي حدود الأيام المتاحة، والفترة ماابتدتش. */
export function validateVisit(dateStr: string, slot: InspectionSlot, now = new Date()): void {
  const today = todayCairo(now);
  if (dateStr < today) throw badRequest('الموعد ده في الماضي');
  if (dateStr > addDays(today, MAX_ADVANCE_DAYS)) {
    throw badRequest(`أقصى مدة للحجز ${MAX_ADVANCE_DAYS} أيام قدّام`);
  }
  if (dateStr === today && cairoHour(now) >= SLOTS[slot].startHour) {
    throw badRequest('الفترة دي ابتدت أو عدّت — اختار فترة تانية');
  }
}
