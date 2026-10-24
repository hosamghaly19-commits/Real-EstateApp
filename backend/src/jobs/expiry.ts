import { expireOverdue } from '../services/inspections';

let timer: NodeJS.Timeout | undefined;
let running = false;

/** كل دقيقة: يقفل طلبات المعاينة اللي المعلن ماردّش عليها ويرد الرسوم. */
export function startExpiryJob(intervalMs = 60_000) {
  const tick = async () => {
    if (running) return; // منع التداخل
    running = true;
    try {
      const n = await expireOverdue();
      if (n > 0) console.log(`⏱️  اتقفل ${n} طلب معاينة منتهي (واتردّت رسومهم)`);
    } catch (e) {
      console.error('expiry job failed', e);
    } finally {
      running = false;
    }
  };
  timer = setInterval(tick, intervalMs);
  timer.unref();
  void tick();
}

export function stopExpiryJob() {
  if (timer) clearInterval(timer);
}
