import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(3000),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL مطلوب'),
  CORS_ORIGIN: z.string().default('*'),
  DEMO_AUTH: z.enum(['true', 'false']).default('false'),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('❌ إعدادات البيئة غير صحيحة:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}
const env = parsed.data;

export const config = {
  env: env.NODE_ENV,
  port: env.PORT,
  databaseUrl: env.DATABASE_URL,
  corsOrigins:
    env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',').map((s) => s.trim()),
  /**
   * دخول تجريبي (هيدر x-demo-phone) لحد ما نبني الـ Auth الحقيقي.
   * شغّال في التطوير والاختبار، وفي production لازم يتفعّل صراحةً (مش مُوصى).
   */
  demoAuth: env.NODE_ENV !== 'production' || env.DEMO_AUTH === 'true',
};
