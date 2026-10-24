import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { demoAuth } from './middleware/auth';
import { errorHandler, notFoundHandler } from './middleware/error';
import { propertiesRouter } from './routes/properties';
import { metaRouter } from './routes/meta';
import { inspectionsRouter } from './routes/inspections';

export const app = express();

app.disable('x-powered-by');
app.set('trust proxy', 1); // Render بيحط proxy قدام التطبيق
app.use(helmet());
app.use(cors({ origin: config.corsOrigins }));
app.use(express.json({ limit: '100kb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.use(
  '/api',
  rateLimit({ windowMs: 60_000, limit: 300, standardHeaders: true, legacyHeaders: false }),
  demoAuth,
);
app.use('/api/properties', propertiesRouter);
app.use('/api/inspections', inspectionsRouter);
app.use('/api', metaRouter);

app.use(notFoundHandler);
app.use(errorHandler);
