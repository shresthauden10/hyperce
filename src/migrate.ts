import { runMigrations } from '@vendure/core';
import { config } from './vendure-config';

runMigrations(config)
    .then(() => {
        console.log('Migrations completed successfully.');
        process.exit(0);
    })
    .catch(err => {
        console.error('Migration failed:', err);
        process.exit(1);
    });