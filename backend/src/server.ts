import { app } from './app';
import { config } from './config';
import { prisma } from './db';
import { startExpiryJob, stopExpiryJob } from './jobs/expiry';

const server = app.listen(config.port, () => {
  console.log(`🚀 API شغّال على http://localhost:${config.port}  (${config.env})`);
  if (config.demoAuth) console.warn('⚠️  الدخول التجريبي (x-demo-phone) مفعّل');
  startExpiryJob();
});

async function shutdown(signal: string) {
  console.log(`${signal} — بنقفل...`);
  stopExpiryJob();
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}
process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));
