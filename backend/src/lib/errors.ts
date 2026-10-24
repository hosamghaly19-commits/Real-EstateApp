export class AppError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
  }
}

export const notFound = (msg = 'مش موجود') => new AppError(404, 'NOT_FOUND', msg);
export const forbidden = (msg = 'مش مسموح لك بالعملية دي') =>
  new AppError(403, 'FORBIDDEN', msg);
export const badRequest = (msg: string, details?: unknown) =>
  new AppError(400, 'BAD_REQUEST', msg, details);
