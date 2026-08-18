import { initializeApp } from 'firebase-admin/app';

// Firebase Admin SDK — shared by all triggers.
initializeApp();

export * from './matching';
export * from './accept';
export * from './jobs';
export * from './chat';
export * from './reviews';
export * from './payments';
export * from './complaints';
export * from './admin';
export * from './subscriptions';
export * from './training';
