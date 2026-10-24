import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../lib/errors';
import { config } from '../config';

export const notFoundHandler: RequestHandler = (_req, res) => {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'المسار ده مش موجود' } });
};

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'بيانات غير صالحة',
        details: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      },
    });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details },
    });
    return;
  }
  // JSON مكسور في الـ body
  if (err?.type === 'entity.parse.failed') {
    res.status(400).json({ error: { code: 'BAD_JSON', message: 'الـ JSON مش صحيح' } });
    return;
  }
  console.error(err);
  res.status(500).json({
    error: {
      code: 'INTERNAL',
      message: 'حصل خطأ غير متوقع',
      ...(config.env === 'production' ? {} : { debug: String(err?.message ?? err) }),
    },
  });
};
