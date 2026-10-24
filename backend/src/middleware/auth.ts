import type { RequestHandler } from 'express';
import type { AccountType, UserRole } from '@prisma/client';
import { prisma } from '../db';
import { config } from '../config';
import { AppError } from '../lib/errors';

export interface AuthUser {
  id: string;
  role: UserRole;
  accountType: AccountType;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

/**
 * ⚠️ دخول تجريبي مؤقت: هيدر `x-demo-phone: 0100...` بيحدد المستخدم.
 * TODO: يتبدل بالـ Auth الحقيقي (JWT) — القرار: OTP ولا Password.
 */
export const demoAuth: RequestHandler = async (req, _res, next) => {
  if (!config.demoAuth) return next();
  const phone = req.header('x-demo-phone');
  if (!phone) return next();

  const user = await prisma.user.findUnique({
    where: { phone },
    select: { id: true, role: true, accountType: true, isActive: true },
  });
  if (!user || !user.isActive) {
    throw new AppError(401, 'UNAUTHENTICATED', 'المستخدم ده مش موجود أو موقوف');
  }
  req.user = { id: user.id, role: user.role, accountType: user.accountType };
  next();
};

export const requireAuth: RequestHandler = (req, _res, next) => {
  if (!req.user) {
    throw new AppError(401, 'UNAUTHENTICATED', 'لازم تسجّل الدخول الأول');
  }
  next();
};
